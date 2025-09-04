//
//  MarketWidgets.swift
//  MarketWidgets
//
//  Created by Edwin Bosire on 04/09/2025.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Models
struct QuoteSnapshot: Codable, Hashable {
	let symbol: String
	let fullname: String
	let price: Double
	let changePct: Double
	let sparkline: [Double]
	let ts: Date
}

// MARK: - Timeline
struct MarketEntry: TimelineEntry {
	let date: Date
	let quotes: [QuoteSnapshot]
}

struct MarketProvider: TimelineProvider {
	func placeholder(in context: Context) -> MarketEntry {
		MarketEntry(date: .now, quotes: DemoData.quotes)
	}

	func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
		completion(MarketEntry(date: .now, quotes: DemoData.quotes))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
		// In production: read from App Group cache, or inject via shared package
		let entry = MarketEntry(date: .now, quotes: DemoData.quotes)
		// Refresh hint (system may coalesce). Keep moderate.
		let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
		completion(Timeline(entries: [entry], policy: .after(next)))
	}
}

// MARK: - View
struct MarketWidgetView: View {
	let entry: MarketEntry

	var body: some View {
		VStack(spacing: 4) {
			ForEach(entry.quotes.prefix(4), id: \.symbol) { quote in
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						VStack(alignment: .leading) {
							Text(quote.symbol)
								.font(.headline)
								.bold()
							Text(quote.fullname)
								.font(.caption)
								.foregroundStyle(.secondary)

						}
						Spacer()

						Sparkline(values: quote.sparkline,
								  strokeColor: quote.changePct >= 0 ? .green : .red)
							.frame(width: 80, height: 30)
							.accessibilityLabel("Sparkline for \(quote.symbol)")

						VStack(alignment: .trailing, spacing: 2.0) {
							Text(Self.fmtPrice(quote.price))
								.font(.footnote)
								.monospacedDigit()
							Text(Self.fmtPct(quote.changePct))
								.font(.footnote)
								.bold()
								.foregroundStyle(.white)
//								.padding(5)
								.padding(.vertical, 4)
								.padding(.leading, 8)
								.background(quote.changePct >= 0 ? .green : .red)
								.cornerRadius(8)
						}
					}
				}
				if quote.symbol != entry.quotes.prefix(4).last?.symbol {
					Divider()
				}
			}
			HStack {
				Image(systemName: "clock")
				Text("Updated just now")
				Spacer()
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
		.containerBackground(Color.white, for: .widget)
	}

	static func fmtPrice(_ p: Double) -> String {
		String(format: "%.2f", p)
	}
	static func fmtPct(_ pct: Double) -> String {
		let sign = pct >= 0 ? "+" : ""
		return String(format: "%@%.2f%%", sign, pct)
	}
}

// MARK: - Sparkline
struct Sparkline: View {
	let values: [Double]
	let strokeColor: Color

	// Map a sample to a point
	func point(_ width: CGFloat, _ height: CGFloat, _ i: Int, _ v: Double, _ minV: Double = 0, _ range: Double = 1) -> CGPoint {
		let x = width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
		let yNorm = (v - minV) / range
		let y = height * (1 - CGFloat(yNorm))
		return CGPoint(x: x, y: y)
	}

	var body: some View {
		GeometryReader { geo in
			let minV = values.min() ?? 0
			let maxV = values.max() ?? 1
			let range = max(maxV - minV, 0.0001)

			let width  = geo.size.width
			let height = geo.size.height


			// 1) Polyline
			let linePath: Path = Path { p in
				for (i, v) in values.enumerated() {
					let pt = point(width, height, i, v, minV, range)
					if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
				}
			}

			// 2) Filled area under the line (closed to baseline)
			let fillPath: Path = Path { p in
				p.move(to: CGPoint(x: 0, y: height))                  // start baseline left
				for (i, v) in values.enumerated() {
					p.addLine(to: point(width, height, i, v, minV, range))
				}
				p.addLine(to: CGPoint(x: width, y: height))           // down to baseline right
				p.closeSubpath()
			}

			// 3) Average line (dashed)
			let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
			let yAvgNorm = (avg - minV) / range
			let yAvg = height * (1 - CGFloat(yAvgNorm))

			// Draw: fill → line → avg dash
			fillPath
				.fill(strokeColor.opacity(0.12))

			linePath
				.stroke(lineWidth: 1.5)
				.fill(strokeColor)

			Path { p in
				p.move(to: CGPoint(x: 0,     y: yAvg))
				p.addLine(to: CGPoint(x: width, y: yAvg))
			}
			.stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
			.foregroundStyle(.secondary)
		}
		.accessibilityLabel("Sparkline with average")
	}
}

// MARK: - Widget
struct MarketWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(
			kind: "com.gs.markets.market",
			provider: MarketProvider()) { entry in
				MarketWidgetView(entry: entry)
			}
		.configurationDisplayName("Market Watch")
		.description("Track selected tickers at a glance.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
	}
}

// MARK: - Demo data
enum DemoData {
	static let quotes: [QuoteSnapshot] = [
		.init(symbol: "JPM", fullname: "JP Morgan Chase & Co", price: 426.12, changePct: 0.72, sparkline: demoLine(start: 420, drift: 0.3), ts: .now),
		.init(symbol: "AAPL", fullname: "Apple Inc.",  price: 196.02, changePct: -0.21, sparkline: demoLine(start: 197, drift: -0.2), ts: .now),
		.init(symbol: "MSFT", fullname: "Microsoft Corporation",  price: 423.44, changePct: 0.35, sparkline: demoLine(start: 420, drift: 0.1), ts: .now),
		.init(symbol: "NVDA", fullname: "Nvidia Corporation",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now)
	]

	static func demoLine(start: Double, drift: Double) -> [Double] {
		let n = 30
		var v = start
		return (0..<n).map { _ in
			v += Double.random(in: -0.6...0.6) + drift
			return max(0.01, v)
		}
	}
}

#Preview(as: .systemLarge) {
	MarketWidget()
} timeline: {
	MarketEntry(date: .now, quotes: DemoData.quotes)
}

#Preview(as: .systemMedium) {
	MarketWidget()
} timeline: {
	MarketEntry(date: .now, quotes: DemoData.quotes)
}
