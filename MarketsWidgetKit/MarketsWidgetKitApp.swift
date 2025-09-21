//
//  MarketsWidgetKitApp.swift
//  MarketsWidgetKit
//
//  Created by Edwin Bosire on 04/09/2025.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct MarketsWidgetKitApp: App {
	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			Item.self,
		])
		let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

		do {
			return try ModelContainer(for: schema, configurations: [modelConfiguration])
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}()

	var body: some Scene {
		WindowGroup {
			WidgetsPrototypeView()
		}
		.modelContainer(sharedModelContainer)
	}
}

#Preview {
	WidgetsPrototypeView()
}
// MARK: - Widgets Prototype (in-app simulation)

import Foundation

struct QuoteSnapshot: Codable, Hashable {
	let symbol: String
	let fullname: String
	let price: Double
	let changePct: Double
	let sparkline: [Double]
	let ts: Date
}

struct ResearchItemLite: Codable, Hashable {
	let id: String
	let title: String
	let teaser: String
	let deeplink: URL?
	let ts: Date
}

struct WidgetsPrototypeView: View {
	@State private var quotes: [QuoteSnapshot] = DemoData.quotes
	@State private var research: [ResearchItemLite] = DemoData.research

	var body: some View {
		NavigationStack {
			List {
				Section("Market Widget (prototype)") {
					MarketWidgetCard(quotes: quotes)
						.padding(.vertical, 4)
					Button("Randomize Market Data") {
						quotes = DemoData.randomizedQuotes(from: quotes)
					}
				}

				Section("Research Widget (prototype)") {
					ResearchWidgetCard(items: research)
						.padding(.vertical, 4)
					Button("Shuffle Headlines") {
						research.shuffle()
					}
				}

				Section("Actions") {
					Button("Pretend to Reload Real Widgets") {
						WidgetCenter.shared.reloadAllTimelines()
					}
					.buttonStyle(.borderedProminent)
					.disabled(false)
				}
			}
			.navigationTitle("Widgets Prototype")
		}
	}
}

// MARK: - Market widget card (simulated)
struct MarketWidgetCard: View {
	let quotes: [QuoteSnapshot]

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(quotes.prefix(4), id: \.symbol) { quote in
				VStack(alignment: .leading, spacing: 4) {
					HStack(alignment: .bottom) {
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
							Text(Self.fmtPrice(quote.price))
								.font(.footnote)
								.monospacedDigit()
							Text(Self.fmtPct(quote.changePct))
								.font(.footnote)
								.bold()
								.foregroundStyle(.white)
								.padding(5)
								.padding(.leading, 8)
								.background(quote.changePct >= 0 ? .green : .red)
								.cornerRadius(8)
						}
					}
				}
				if quote.symbol != quotes.prefix(4).last?.symbol {
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
	}

	static func fmtPrice(_ p: Double) -> String {
		String(format: "%.2f", p)
	}
	static func fmtPct(_ pct: Double) -> String {
		let sign = pct >= 0 ? "+" : ""
		return String(format: "%@%.2f%%", sign, pct)
	}
}

// MARK: - Research widget card (simulated)
struct ResearchWidgetCard: View {
	let items: [ResearchItemLite]

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(items.prefix(3), id: \.id) { item in
				VStack(alignment: .leading, spacing: 2) {
					Text(item.title)
						.font(.caption)
						.bold()
						.lineLimit(2)
					Text(item.teaser)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				if item.id != items.prefix(3).last?.id { Divider() }
			}
			HStack {
				Image(systemName: "lock")
				Text("Lock Screen privacy supported")
				Spacer()
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
	}
}

// MARK: - Demo Data
enum DemoData {
	static let quotes: [QuoteSnapshot] = [
		.init(symbol: "JPM", fullname: "JP Morgan Chase & Co", price: 426.12, changePct: 0.72, sparkline: demoLine(start: 420, drift: 0.3), ts: .now),
		.init(symbol: "AAPL", fullname: "Apple Inc.",  price: 196.02, changePct: -0.21, sparkline: demoLine(start: 197, drift: -0.2), ts: .now),
		.init(symbol: "MSFT", fullname: "Microsoft Corporation",  price: 423.44, changePct: 0.35, sparkline: demoLine(start: 420, drift: 0.1), ts: .now),
		.init(symbol: "NVDA", fullname: "Nvidia Corporation",  price: 117.30, changePct: 1.92, sparkline: demoLine(start: 114, drift: 0.6), ts: .now)
	]

	static func randomizedQuotes(from base: [QuoteSnapshot]) -> [QuoteSnapshot] {
		base.map { q in
			let delta = Double.random(in: -0.8...0.8)
			let newPrice = max(0.01, q.price * (1 + delta/100))
			let newPct = q.changePct + delta
			return QuoteSnapshot(symbol: q.symbol,
								 fullname: q.fullname,
								 price: newPrice,
								 changePct: newPct,
								 sparkline: demoLine(start: newPrice, drift: delta/2),
								 ts: .now)
		}
	}

	static let research: [ResearchItemLite] = [
		.init(id: "r1", title: "US Banks: Capital markets rebound drives EPS beats", teaser: "3Q preview: FICC normalization vs ECM recovery.", deeplink: nil, ts: .now),
		.init(id: "r2", title: "Semis: AI accelerator demand outlook 2026+", teaser: "Supply chain checks point to cooling GPU lead times.", deeplink: nil, ts: .now),
		.init(id: "r3", title: "Energy: Brent at $85—positioning and risks", teaser: "OPEC+ discipline offsets non-OPEC growth.", deeplink: nil, ts: .now)
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

#Preview {
	ZStack {
		Color.black.opacity(0.2)
			.ignoresSafeArea(.all)
		VStack(alignment: .leading) {
			MarketWidgetCard(quotes: DemoData.quotes)
				.padding()
				.background(Color.white)
				.clipShape(RoundedRectangle(cornerRadius: 20))
				.padding()

			ResearchWidgetCard(items: DemoData.research)
				.padding()
				.background(Color.white)
				.clipShape(RoundedRectangle(cornerRadius: 20))
				.padding()

		}
//		.background(.red)
	}
}
