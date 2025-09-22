import SwiftUI

public struct SparkLine: View {
	var values: AnimatableVector
	var lineWidth: CGFloat
	let positiveColor: Color
	let negativeColor: Color
	let interpolate: Bool
	let samplesPerSegment: Int = 10

	var animatableData: AnimatableVector {
		get { AnimatableVector(normY) }
		set { normY = newValue.values }
	}

	private var normY: [CGFloat]
	private var avgNorm: CGFloat   // average in 0...1 space

	public init(values: [Double], lineWidth: CGFloat = 2, positiveColor: Color = .green, negativeColor: Color = .red, interpolate: Bool = true) {

		self.init(values: AnimatableVector(values),
			 lineWidth: lineWidth,
			 positiveColor: positiveColor,
			 negativeColor: negativeColor,
			 interpolate: interpolate)
	}

	public init(values: AnimatableVector, lineWidth: CGFloat = 2, positiveColor: Color = .green, negativeColor: Color = .red, interpolate: Bool = true) {
		self.values = values
		self.lineWidth = lineWidth
		self.positiveColor = positiveColor
		self.negativeColor = negativeColor
		self.interpolate = interpolate


		// Normalize once (independent of geometry) so animation targets are correct.
		let verticalPadFraction: Double = 0.06
		let minV = values.values.min() ?? 0
		let maxV = values.values.max() ?? 1
		let span = max(maxV - minV, 1e-9)
		let pad = span * verticalPadFraction
		let lo = minV - pad, hi = maxV + pad
		let padded = max(hi - lo, 1e-9)
		let avg = values.average

		self.normY = values.values.map { CGFloat(($0 - lo) / padded) } // 0 (low) … 1 (high)
		self.avgNorm = CGFloat((avg - lo) / padded)
	}

	var positiveGradient: Gradient {
		Gradient(colors: [positiveColor.opacity(0.4), positiveColor.opacity(0.1), positiveColor.opacity(0.05), .clear])
	}

	var negativeGradient: Gradient {
		Gradient(colors: [negativeColor.opacity(0.3), negativeColor.opacity(0.1), negativeColor.opacity(0.05)])
	}

	public var body: some View {
		GeometryReader { geo in
			let size = geo.size

			let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0

			// Map normalized Y to pixel Y (invert because top-left origin)
			let base = normY.enumerated().map { i, n in CGPoint(x: CGFloat(i) * stepX, y: (1 - n) * size.height) }
			let yAvg = (1 - avgNorm) * size.height

			// 4) Interpolate to smooth if desired
			let points = interpolate ? interpolateCatmullRom(base, samplesPerSegment: samplesPerSegment) : base
			let segments = coloredSegments(points: points, avgY: yAvg)

			Canvas { ctx, sz in
				guard points.count >= 2 else { return }

				// 1) Average dashed line negative segments
				for (a, b) in segments.below {
					var avgPath = Path()
					avgPath.move(to: CGPoint(x: a.x, y: yAvg))
					avgPath.addLine(to: CGPoint(x: b.x, y: yAvg))
					ctx.stroke(avgPath, with: .color(negativeColor.opacity(0.3)),
							   style: StrokeStyle(lineWidth: 1, dash: [2, 1]))
				}

				// 1) Average dashed line positive segments
				for seg in segments.above {
					var avgPath = Path()
					avgPath.move(to: CGPoint(x: seg.0.x, y: yAvg))
					avgPath.addLine(to: CGPoint(x: seg.1.x, y: yAvg))
					ctx.stroke(avgPath, with: .color(positiveColor.opacity(0.3)),
							   style: StrokeStyle(lineWidth: 1, dash: [2, 1]))
				}

				// 2) Split the polyline into contiguous chunks above/below the average
				let chunks = splitChunks(points: points, avgY: yAvg)

				// 3) FILLS
				// Above-average chunks -> fill to the floor (bottom)
				for chunk in chunks.above {
					guard chunk.count >= 2 else { continue }
					var p = Path()
					p.move(to: chunk.first!)
					chunk.dropFirst().forEach { p.addLine(to: $0) }
					// Close polygon to avg line
					if let last = chunk.last, let first = chunk.first {
						p.addLine(to: CGPoint(x: last.x, y: yAvg))
						p.addLine(to: CGPoint(x: first.x, y: yAvg))
						p.closeSubpath()
					}
					ctx.fill(p,
							 with: .linearGradient(positiveGradient,
													 startPoint: CGPoint(x: 0, y: 0),
																						endPoint: CGPoint(x: 0, y: size.height)) )
				}

				// Below-average chunks -> fill up to the average line
				for chunk in chunks.below {
					guard chunk.count >= 2 else { continue }
					var p = Path()
					// start on the avg line vertically above the first x
					if let first = chunk.first, let last = chunk.last {
						p.move(to: CGPoint(x: first.x, y: yAvg))
						p.addLine(to: first)
						chunk.dropFirst().forEach { p.addLine(to: $0) }
						// back to avg line at the last x
						p.addLine(to: CGPoint(x: last.x, y: yAvg))
						p.closeSubpath()
					}
					ctx.fill(p,
							 with: .linearGradient(negativeGradient,
													 startPoint: CGPoint(x: 0, y: size.height),
																						endPoint: CGPoint(x: 0, y: 0)) )
				}
			}
			.onAppear {
				// 2 seconds delay to allow initial layout to settle
				DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
					withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {

//						yVector = AnimatableVector(base)
					}
				}
			}
			.padding(.bottom, 00)
			.overlay {
				Canvas { ctx, sz in
					guard points.count >= 2 else { return }

					// 1) Volume bars
					for (i, pt) in base.enumerated() {
						let origin = CGPoint(x: pt.x, y: size.height - normY[i]*10)
						let size = CGSize(width: stepX-1, height: normY[i]*10)

						let shape = Rectangle()
							.path(in: .init(origin: origin, size: size))

						ctx.fill(shape,
								 with: .color(.gray.opacity(0.2)),
								 style: FillStyle(eoFill: true, antialiased: true))
					}
				}

			}
			.overlay {
				strokeLines(above: segments.above, below: segments.below)
					.clipShape(RoundedRectangle(cornerRadius: 6) )
			}
		}
	}
	func strokeLines(above: [(CGPoint, CGPoint)], below: [(CGPoint, CGPoint)], lineWidth: CGFloat = 3) -> some View {
		Canvas { ctx, sz in
			// 4) STROKES (same color logic as before)
			// below -> red
			for (a,b) in below {
				var p = Path()
				p.move(to: a)
				p.addLine(to: b)
				ctx.stroke(p, with: .color(negativeColor),
						   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .bevel))
			}

			// above -> green
			for (a,b) in above {
				var p = Path()
				p.move(to: a)
				p.addLine(to: b)
				ctx.stroke(p, with: .color(positiveColor),
						   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .bevel))
			}

		}
	}
	// MARK: - Layout helpers

	// Map values -> points with vertical padding to avoid touching edges.
	func layoutPoints(_ values: [CGFloat], in size: CGSize, padFraction: Double = 0.05)
	-> ([CGPoint], CGFloat) {
		guard !values.isEmpty else { return ([], size.height/2) }

		let minV = values.min()!
		let maxV = values.max()!
		let span = max(maxV - minV, 1e-9)
		let pad = span * padFraction
		let lo = minV - pad
		let hi = maxV + pad
		let paddedSpan = max(hi - lo, 1e-9)

		let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0

		func y(for v: CGFloat) -> CGFloat {
			let t = (v - lo) / paddedSpan
			return CGFloat(1 - t) * size.height
		}

		let pts = values.enumerated().map { i, v in CGPoint(x: CGFloat(i) * stepX, y: y(for: v)) }
		let yAvg = y(for: values.reduce(0, +) / Double(values.count))
		return (pts, yAvg)
	}

	func clampToRect(_ pts: [CGPoint], rect: CGRect) -> [CGPoint] {
		pts.map { CGPoint(x: min(max($0.x, rect.minX), rect.maxX),
						  y: min(max($0.y, rect.minY), rect.maxY)) }
	}
	// MARK: - Splitting & coloring

	private func intersection(_ p1: CGPoint, _ p2: CGPoint, y: CGFloat) -> CGPoint? {
		let dy = p2.y - p1.y
		if abs(dy) < 1e-9 { return nil }
		let t = (y - p1.y) / dy
		guard t >= 0, t <= 1 else { return nil }
		return CGPoint(x: p1.x + t * (p2.x - p1.x), y: y)
	}

	private func splitChunks(points: [CGPoint], avgY: CGFloat)
	-> (above: [[CGPoint]], below: [[CGPoint]]) {
		let eps: CGFloat = 1e-9
		var above: [[CGPoint]] = []
		var below: [[CGPoint]] = []

		var current: [CGPoint] = []
		enum Side { case above, below, on }
		func side(_ y: CGFloat) -> Side {
			if y < avgY - eps { return .above }
			if y > avgY + eps { return .below }
			return .on
		}

		var currentSide: Side = .on

		for i in 0..<(points.count - 1) {
			let a = points[i], b = points[i + 1]
			let sa = side(a.y), sb = side(b.y)

			if current.isEmpty {
				current.append(a)
				currentSide = sa == .on ? sb : sa
			}

			if sa == sb || sb == .on {
				// continue the same side (or land on the line)
				current.append(b)
				if sb == .on {
					// close on the line; push and reset
					if currentSide == .above { above.append(current) } else { below.append(current) }
					current = [b]     // start a fresh chunk from the line point
					currentSide = .on
				}
			} else if sa == .on {
				// starting exactly on the line: start new chunk toward b's side
				currentSide = sb
				current = [a, b]
			} else {
				// crossing: split at intersection
				if let xpt = intersection(a, b, y: avgY) {
					current.append(xpt)
					if currentSide == .above { above.append(current) } else { below.append(current) }
					// start new chunk on the other side from the intersection
					current = [xpt, b]
					currentSide = (currentSide == .above) ? .below : .above
				} else {
					// parallel near-avg; just continue
					current.append(b)
				}
			}
		}

		if current.count >= 2 {
			if currentSide == .above { above.append(current) }
			else if currentSide == .below { below.append(current) }
			// if .on with no length, ignore
		}

		return (above, below)
	}

	private func coloredSegments(points: [CGPoint], avgY: CGFloat)
	-> (above: [(CGPoint, CGPoint)], below: [(CGPoint, CGPoint)]) {
		var above: [(CGPoint, CGPoint)] = []
		var below: [(CGPoint, CGPoint)] = []

		for i in 0..<(points.count - 1) {
			let a = points[i], b = points[i + 1]
			let aAbove = a.y < avgY - 1e-9
			let bAbove = b.y < avgY - 1e-9
			let aBelow = a.y > avgY + 1e-9
			let bBelow = b.y > avgY + 1e-9

			if (aAbove && bAbove) || (aBelow && bBelow) {
				if aAbove { above.append((a, b)) } else { below.append((a, b)) }
			} else if let xpt = intersection(a, b, y: avgY) {
				if a.y < avgY {
					above.append((a, xpt))
					below.append((xpt, b))
				} else if a.y > avgY {
					below.append((a, xpt))
					above.append((xpt, b))
				}
			}
		}
		return (above, below)
	}

	// MARK: - Interpolation (Catmull–Rom)

	/// Generates interpolated points along a Catmull–Rom spline.
	/// - Parameters:
	///   - points: Control points to interpolate through (must be at least 2).
	///   - samplesPerSegment: Number of interpolated points per segment.
	/// - Returns: An array of smoothly interpolated points.
	func interpolateCatmullRom(_ points: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
		guard points.count >= 2, samplesPerSegment > 0 else { return points }
		var output: [CGPoint] = []
		let n = points.count

		func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, t: CGFloat) -> CGPoint {
			let t2 = t * t
			let t3 = t2 * t
			let x = 0.5 * (
				(2 * p1.x) +
				(-p0.x + p2.x) * t +
				(2*p0.x - 5*p1.x + 4*p2.x - p3.x) * t2 +
				(-p0.x + 3*p1.x - 3*p2.x + p3.x) * t3
			)
			let y = 0.5 * (
				(2 * p1.y) +
				(-p0.y + p2.y) * t +
				(2*p0.y - 5*p1.y + 4*p2.y - p3.y) * t2 +
				(-p0.y + 3*p1.y - 3*p2.y + p3.y) * t3
			)
			return CGPoint(x: x, y: y)
		}

		for i in 0..<(n - 1) {
			let p0 = i == 0 ? points[i] : points[i - 1]
			let p1 = points[i]
			let p2 = points[i + 1]
			let p3 = (i + 2 < n) ? points[i + 2] : points[i + 1]

			// Always start with p1 (but avoid duplicates)
			if output.isEmpty { output.append(p1) }

			// Interpolated points between p1 and p2
			for s in 1...samplesPerSegment {
				let t = CGFloat(s) / CGFloat(samplesPerSegment + 1)
				output.append(catmullRom(p0, p1, p2, p3, t: t))
			}

			// End with p2
			output.append(p2)
		}

		return output
	}}




// MARK: - Demo

struct SparkLine_Previews: PreviewProvider {
	struct Container: View {
		@State private var series: [Double] = (0..<20).map { _ in Double.random(in: 9...21) }
		@State private var toggle = false
		var body: some View {
			VStack {
			VStack(spacing: 16) {
				Text("Sparkline with Area Fills")
					.font(.headline)

				SparkLine(values: toggle ? seriesShuffled : series)
					.frame(height: 100)
					.padding(.horizontal)
					.padding(.vertical, 4)
					.border(.gray.opacity(0.3))
					.animation(.easeInOut(duration: 0.9), value: toggle)

				Button("Randomize") {
					withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
						toggle.toggle()
						series = series.map { _ in CGFloat.random(in: 8...20) }
						print("New values: \(series)")
					}
				}
				.buttonStyle(.borderedProminent)
			}

				VStack(spacing: 16) {
					Text("Sparkline with flat series")
						.font(.headline)

					SparkLine(values: [5, 5, 5, 5, 5]) // flat series
						.frame(height: 90)
						.padding(.horizontal)
						.border(.gray.opacity(0.3))

				}
			}
			.padding()

		}

		private var seriesShuffled: [Double] { var v = series; v.shuffle(); return v } // same length

	}

	static var previews: some View {
		Container()
		.previewLayout(.sizeThatFits)
	}
}

extension Array where Element == Double {
	var average: Double {
		guard !isEmpty else { return 0 }
		return reduce(0, +) / Double(count)
	}
}
