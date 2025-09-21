import SwiftUI

public struct SparkLine: View {
	let values: [Double]
	var lineWidth: CGFloat = 2
	let positiveColor: Color //=
	let negativeColor: Color //= Color.red

	public init(values: [Double], lineWidth: CGFloat = 2, positiveColor: Color = .green, negativeColor: Color = .red) {
		self.values = values
		self.lineWidth = lineWidth
		self.positiveColor = positiveColor
		self.negativeColor = negativeColor
	}

	public var body: some View {
		GeometryReader { geo in
			let size = geo.size
			let avg = values.average
			let (points, yAvg) = layoutPoints(values: values, in: size, avg: avg)

			Canvas { ctx, sz in
				guard points.count >= 2 else { return }

				// 1) Average dashed line
				var avgPath = Path()
				avgPath.move(to: CGPoint(x: 0, y: yAvg))
				avgPath.addLine(to: CGPoint(x: sz.width, y: yAvg))
				ctx.stroke(avgPath,
						   with: .color(.secondary),
						   style: StrokeStyle(lineWidth: 1, dash: [6, 4]))

				// 2) Split the polyline into contiguous chunks above/below the average
				let chunks = splitChunks(points: points, avgY: yAvg)

				// 3) FILLS
				// Above-average chunks -> fill to the floor (bottom)
				for chunk in chunks.above {
					guard chunk.count >= 2 else { continue }
					var p = Path()
					p.move(to: chunk.first!)
					chunk.dropFirst().forEach { p.addLine(to: $0) }
					// Close polygon to floor
					if let last = chunk.last, let first = chunk.first {
						p.addLine(to: CGPoint(x: last.x, y: yAvg))
						p.addLine(to: CGPoint(x: first.x, y: yAvg))
						p.closeSubpath()
					}
					ctx.fill(p, with: .color(positiveColor.opacity(0.2)))
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
					ctx.fill(p, with: .color(negativeColor.opacity(0.2)))
				}

				// 4) STROKES (same color logic as before)
				// below -> red
				for seg in coloredSegments(points: points, avgY: yAvg).below {
					var p = Path()
					p.move(to: seg.0)
					p.addLine(to: seg.1)
					ctx.stroke(p, with: .color(negativeColor),
							   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				}
				// above -> green
				for seg in coloredSegments(points: points, avgY: yAvg).above {
					var p = Path()
					p.move(to: seg.0)
					p.addLine(to: seg.1)
					ctx.stroke(p, with: .color(positiveColor),
							   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				}
			}
		}
	}

	// MARK: - Layout helpers

	private func layoutPoints(values: [Double], in size: CGSize, avg: Double) -> ([CGPoint], CGFloat) {
		guard !values.isEmpty else { return ([], size.height/2) }

		let minV = values.min() ?? 0
		let maxV = values.max() ?? 1
		let span = max(maxV - minV, 1e-9)

		let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0

		func y(for v: Double) -> CGFloat {
			let t = (v - minV) / span
			return CGFloat(1 - t) * size.height
		}

		let pts = values.enumerated().map { i, v in
			CGPoint(x: CGFloat(i) * stepX, y: y(for: v))
		}
		return (pts, y(for: avg))
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
}

// MARK: - Helpers

private extension Array where Element == Double {
	var average: Double {
		guard !isEmpty else { return 0 }
		return reduce(0, +) / Double(count)
	}
}

// MARK: - Demo

struct SparkLine_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 16) {
			Text("Sparkline with Area Fills")
				.font(.headline)

			SparkLine(values: [12, 10, 14, 9, 11, 15, 18, 13, 17, 16, 14])
				.frame(height: 100)
				.padding(.horizontal)

			SparkLine(values: [5, 5, 5, 5, 5]) // flat series
				.frame(height: 90)
				.padding(.horizontal)
		}
		.padding()
		.previewLayout(.sizeThatFits)
	}
}
