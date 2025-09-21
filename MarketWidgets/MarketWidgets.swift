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
	@Environment(\.widgetFamily) var family
	let entry: MarketEntry

	var body: some View {
		switch family {
			case .systemSmall:
				smallMarketDataView
			case .systemMedium:
				mediumMarketDataView
			case .systemLarge:
				largeMarketDataView2
			default:
				mediumMarketDataView
					.border(.green)
		}
	}

	var smallMarketDataView: some View {
		VStack(spacing: 0) {
			HStack {
				VStack(alignment: .leading) {
					Text(entry.quotes[1].symbol)
						.font(.body)
						.bold()
						.foregroundStyle(Color("positive"))

					HStack(spacing: 0) {
						Image(systemName: "triangle.fill")
							.foregroundStyle(entry.quotes[1].changePct >= 0 ? .green : .red)
							.rotationEffect(.degrees(entry.quotes[1].changePct >= 0 ? 0 : 180))
						Text(fmtPrice(entry.quotes[1].price))
					}
					.font(.caption)
					.foregroundStyle(entry.quotes[1].changePct >= 0 ? .green : .red)
				}
				Spacer()
				VStack(alignment: .leading) {
					Text(entry.quotes[3].symbol)
						.font(.body)
						.bold()
						.foregroundStyle(Color("positive"))

					HStack(spacing: 0) {
						Image(systemName: "triangle.fill")
							.foregroundStyle(entry.quotes[3].changePct >= 0 ? .green : .red)
							.rotationEffect(.degrees(entry.quotes[3].changePct >= 0 ? 0 : 180))
						Text(fmtPrice(entry.quotes[3].price))
					}
					.font(.caption)
					.foregroundStyle(entry.quotes[3].changePct >= 0 ? .green : .red)
				}
			}
			.padding(.horizontal, 0)
			Divider()
				.padding(.top, 5)
			card(quote: entry.quotes[4])
				.padding(.horizontal, -4)
//			HStack {
//				Image(systemName: "clock")
//				Text("Updated just now")
//				Spacer()
//			}
//			.font(.caption2)
//			.foregroundStyle(.secondary)

		}
		.containerBackground(Color("background"), for: .widget)
	}

	var mediumMarketDataView: some View {
		VStack(spacing: 2) {
			ForEach(entry.quotes.prefix(3), id: \.symbol) { quote in
				InstrumentRow(quote: quote)
			}
			HStack {

				Image(systemName: "clock")
				Text("Updated just now")
				Spacer()
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
		.containerBackground(.fill.tertiary, for: .widget)

	}

	var largeMarketDataView: some View {
		VStack(spacing: 2) {
			ForEach(entry.quotes, id: \.symbol) { quote in
				InstrumentRow(quote: quote)
				if quote.symbol != entry.quotes.last?.symbol {
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

	func card(quote: QuoteSnapshot) -> some View {
		VStack(alignment: .leading) {
			Text(quote.symbol)
				.font(.headline)
				.bold()
				.foregroundStyle(Color("positive"))
			Text("6,6697.36")
				.font(.caption)
				.foregroundStyle(.white)
			SparkLine(values: quote.sparkline)
			.frame(height: 30)
			.accessibilityLabel("Sparkline for \(quote.symbol)")

			HStack {
				Text(fmtPrice(quote.price))
					.font(.caption)
//					.monospacedDigit()

				Text(fmtPct(quote.changePct))
					.font(.caption)
			}
			.foregroundStyle(quote.changePct >= 0 ? .green : .red)
		}
		.padding(4)
//		.border(.black)

	}

	var largeMarketDataView2: some View {
		VStack(spacing: 2) {
			Grid(horizontalSpacing: 0, verticalSpacing: 0) {
				GridRow {
					card(quote:entry.quotes[0])
					card(quote:entry.quotes[1])
					card(quote:entry.quotes[2])
					}


				GridRow {
					card(quote:entry.quotes[3])
					card(quote:entry.quotes[4])
					card(quote:entry.quotes[5])
					}

				GridRow {
					card(quote:entry.quotes[6])
					card(quote:entry.quotes[7])
					card(quote:entry.quotes[8])
					}
				}
			.padding(.horizontal, -2)
			.overlay {
				GeometryReader { geo in
					let w = geo.size.width
					let h = geo.size.height

					Path { p in
						// Vertical separators (1/3 & 2/3)
						p.move(to: CGPoint(x: w/3, y: 0))
						p.addLine(to: CGPoint(x: w/3, y: h))
						p.move(to: CGPoint(x: 2*w/3, y: 0))
						p.addLine(to: CGPoint(x: 2*w/3, y: h))

						// Horizontal separators (1/3 & 2/3)
						p.move(to: CGPoint(x: 0, y: h/3))
						p.addLine(to: CGPoint(x: w, y: h/3))
						p.move(to: CGPoint(x: 0, y: 2*h/3))
						p.addLine(to: CGPoint(x: w, y: 2*h/3))
					}
					.stroke(style: StrokeStyle(
									lineWidth: 1,
									dash: [2, 2] // 6 points drawn, 3 points empty
								))
					.stroke(Color("border").opacity(0.3))
				}
				.padding(.horizontal, 0)
				.border(.secondary)
			}

				HStack {
					Image(systemName: "clock")
					Text("Updated just now")
					Spacer()
				}
				.font(.caption2)
				.foregroundStyle(.secondary)
			}
		.containerBackground(Color("background"), for: .widget)
		}
}

// Row item
struct InstrumentRow: View {
	let quote: QuoteSnapshot

	var body: some View {
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

				SparkLine(values: quote.sparkline)
				.frame(width: 80, height: 30)
				.accessibilityLabel("Sparkline for \(quote.symbol)")

				VStack(alignment: .trailing, spacing: 2.0) {
					Text(fmtPrice(quote.price))
						.font(.footnote)
						.monospacedDigit()
					Text(fmtPct(quote.changePct))
						.font(.footnote)
						.bold()
						.foregroundStyle(.white)
//													.padding(5)
						.padding(.vertical, 4)
						.padding(.leading, 8)
						.background(quote.changePct >= 0 ? .green : .red)
						.cornerRadius(8)
				}
			}
		}
	}
}

func fmtPrice(_ p: Double) -> String {
	String(format: "%.2f", p)
}
func fmtPct(_ pct: Double) -> String {
	let sign = pct >= 0 ? "+" : ""
	return String(format: "%@%.2f%%", sign, pct)
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
		.init(symbol: "NVDA", fullname: "Nvidia Corporation",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now),
		.init(symbol: "INTC", fullname: "Intel Corporation",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now),
		.init(symbol: "TSLA", fullname: "Tesla Inc",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now),
		.init(symbol: "WBD", fullname: "Warner Bros",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: -0.1), ts: .now),
		.init(symbol: "OPEN", fullname: "Open Technology",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now),
		.init(symbol: "SNAP", fullname: "Sna Inc.",  price: 117.30, changePct: -1.22, sparkline: demoLine(start: 114, drift: -0.6), ts: .now)
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

#Preview(as: .systemSmall) {
	MarketWidget()
} timeline: {
	MarketEntry(date: .now, quotes: DemoData.quotes)
}

#Preview(as: .systemMedium) {
	MarketWidget()
} timeline: {
	MarketEntry(date: .now, quotes: DemoData.quotes)
}

#Preview(as: .systemLarge) {
	MarketWidget()
} timeline: {
	MarketEntry(date: .now, quotes: DemoData.quotes)
}

