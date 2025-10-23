//
//  ThresholdCharts.swift
//  MarketsWidgetKit
//
//  Created by Edwin Bosire on 21/10/2025.
//

import Foundation
import SwiftUI
import Charts

//struct ChartPoint: Identifiable, Equatable {
//	let id = UUID()
//	let time: Date
//	let value: Double
//}

struct Segment: Identifiable {
	let id = UUID()
	let isAbove: Bool
	let points: [ChartPoint]
}

struct ChartLineSegment {
	let points: [CGPoint]
	let color: Color
	let lineWidth: CGFloat
}

typealias ChartPoint = (x: Double, y: Double)

struct ChartColors {
	static let blueColor: Color = .blue
	static let redColor: Color = .red
}
struct TrueSegmentedChart: View {
	let data: [ChartPoint]
	let threshold: Double
	let max: ChartPoint
	let min: ChartPoint
	let topInset: CGFloat = 20.0
	let bottomInset: CGFloat = 20
	let zeroLevel: Double = 0.0
	typealias ChartLineSegment = [ChartPoint]

	@State private var fraction: CGFloat = 0
	var colors: (above: Color, below: Color, zeroLevel: Double) {
		(above: ChartColors.blueColor, below: ChartColors.redColor, 0)
	}

	let positive = LinearGradient(colors: [.green.opacity(0.8), .green.opacity(0.1)], startPoint: .top, endPoint: .bottom)
	let negative = LinearGradient(colors: [.red.opacity(0.8), .red.opacity(0.1)], startPoint: .top, endPoint: .bottom)
	init(data: [ChartPoint], threshold: Double) {
		self.data = data
		self.threshold = threshold
		self.max = data.max(by: { $0.y < $1.y }) ?? ChartPoint(x: 0, y: 0)
		self.min = data.min(by: { $0.y < $1.y }) ?? ChartPoint(x: 0, y: 0)
	}

	var body: some View {
		areaChart
			.mask(alignment: .leading) {
				GeometryReader { geo in
					Rectangle()
						.border(.red, width: 4)
						.frame(width: geo.size.width)
						.padding(.leading, -1*fraction * geo.size.width)
				}
			}
			.overlay(alignment: .topTrailing) {
				Button(fraction == 0 ? "Hide" : "Show") {
					withAnimation(.easeInOut(duration: 0.5)) {
						self.fraction = 1-self.fraction
					}
				}
				.padding(8)
			}
		.border(.gray.opacity(0.3))
		.clipShape(Rectangle())
	}

	private var areaChart: some View {
		GeometryReader { geo in
			let segments = segmentLine(data, zeroLevel: colors.zeroLevel)
			ForEach(Array(segments.enumerated()), id: \.offset) { seriesIndex, segment in

				let scaledXValues = scaleValuesOnXAxis( segment.map(\.x), size: geo.size )
				let scaledYValues = scaleValuesOnYAxis( segment.map (\.y), size: geo.size )

				let isAboveZeroLine = scaledYValues.max()! <= scaleValueOnYAxis(colors.zeroLevel, size: geo.size)

				Path { path in
					guard scaledXValues.count > 1, scaledYValues.count > 1 else { return }
					let firstPoint = CGPoint(x: scaledXValues[0], y: scaledYValues[0])
					path.move(to: firstPoint)

					for i in 1..<scaledXValues.count {
						path.addLine(to: CGPoint(x: scaledXValues[i], y: scaledYValues[i]))
					}
				}
				.stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
				.foregroundStyle(isAboveZeroLine ? Color.green : Color.red)

				let zero = CGFloat(getZeroValueOnYAxis(zeroLevel: colors.zeroLevel, size: geo.size)	)

				Path { area in
					guard scaledXValues.count > 1, scaledYValues.count > 1 else { return }
					let firstPoint = CGPoint(x: scaledXValues[0], y: zero)
					area.move(to: firstPoint)

					for i in 1..<scaledXValues.count {
						area.addLine(to: CGPoint(x: scaledXValues[i], y: scaledYValues[i]))
					}
					area.addLine(to: CGPoint(x: CGFloat(scaledXValues.last!), y: zero))
				}
				.fill(isAboveZeroLine ? positive : negative)

			}
		}
		.padding(.top, topInset)
		.padding(.bottom, bottomInset)

	}
	func segmentLine(_ line: ChartLineSegment, zeroLevel: Double) -> [ChartLineSegment] {
		var segments: [ChartLineSegment] = []
		var segment: ChartLineSegment = []

		line.enumerated().forEach { (i, point) in
			segment.append(point)
			if i < line.count - 1 {
				let nextPoint = line[i+1]
				if point.y >= zeroLevel && nextPoint.y < zeroLevel || point.y < zeroLevel && nextPoint.y >= zeroLevel {
					// The segment intersects zeroLevel, close the segment with the intersection point
					let closingPoint = intersectionWithLevel(point, and: nextPoint, level: zeroLevel)
					segment.append(closingPoint)
					segments.append(segment)
					// Start a new segment
					segment = [closingPoint]
				}
			} else {
				// End of the line
				segments.append(segment)
			}
		}
		return segments
	}

	private func intersectionWithLevel(_ p1: ChartPoint, and p2: ChartPoint, level: Double) -> ChartPoint {
		let dy1 = level - p1.y
		let dy2 = level - p2.y
		return (x: (p2.x * dy1 - p1.x * dy2) / (dy1 - dy2), y: level)
	}

	private func scaleValuesOnXAxis(_ values: [Double], size: CGSize) -> [Double] {
		let width = size.height

		var factor: Double
		if max.x - min.x == 0 {
			factor = 0
		} else {
			factor = width / (max.x - min.x)
		}

		let scaled = values.map { factor * ($0 - self.min.x) }
		return scaled
	}


	private func scaleValuesOnYAxis(_ values: [Double], size: CGSize) -> [Double] {
		let height = size.height
		var factor: Double
		if max.y - min.y == 0 {
			factor = 0
		} else {
			factor = height / (max.y - min.y)
		}

		let scaled = values.map { Double(self.topInset) + height - factor * ($0 - self.min.y) }

		return scaled
	}

	private func scaleValueOnYAxis(_ value: Double, size: CGSize) -> Double {
		let height = size.height
		var factor: Double
		if max.y - min.y == 0 {
			factor = 0
		} else {
			factor = height / (max.y - min.y)
		}

		let scaled = Double(self.topInset) + height - factor * (value - min.y)
		return scaled
	}

	private func getZeroValueOnYAxis(zeroLevel: Double, size: CGSize) -> Double {
		if min.y > zeroLevel {
			return scaleValueOnYAxis(min.y, size: size)
		} else {
			return scaleValueOnYAxis(zeroLevel, size: size)
		}
	}
}

extension Sequence where Element == Double {
	func minOrZero() -> Double {
		return self.min() ?? 0.0
	}
	func maxOrZero() -> Double {
		return self.max() ?? 0.0
	}
}
private struct BelendedChartContentView: View {
	@State private var data: [ChartPoint] = []
	private let start = Date()
	private let threshold = 50.0

	var body: some View {
		VStack {
			TrueSegmentedChart(data: data, threshold: threshold)
				.frame(width: 320, height: 180)
			Text("Blended Red ↔ Green Sparkline")
				.font(.caption)
				.foregroundColor(.gray)

			Button("shuffle") {
				withAnimation(.bouncy) {
					data = (0...30)
						.map { i in ChartPoint(x: Double(i), y: Double.random(in: -100...100))}
				}

			}
		}
		.task {
			data = (0...30)
				.map { i in ChartPoint(x: Double(i), y: Double.random(in: -100...100))}
		}
	}
}

#Preview("Threshold Chart") {
	BelendedChartContentView()
}
