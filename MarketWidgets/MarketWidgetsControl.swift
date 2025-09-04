//
//  MarketWidgetsControl.swift
//  MarketWidgets
//
//  Created by Edwin Bosire on 04/09/2025.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Models
struct ResearchItemLite: Codable, Hashable {
	let id: String
	let title: String
	let teaser: String
	let deeplink: URL?
	let ts: Date
}

// MARK: - Timeline
struct ResearchEntry: TimelineEntry {
	let date: Date
	let items: [ResearchItemLite]
}

struct ResearchProvider: TimelineProvider {
	func placeholder(in context: Context) -> ResearchEntry {
		ResearchEntry(date: .now, items: demoItems)
	}

	func getSnapshot(in context: Context, completion: @escaping (ResearchEntry) -> Void) {
		completion(ResearchEntry(date: .now, items: demoItems))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<ResearchEntry>) -> Void) {
		// In production: read from App Group cache (e.g., research_cache.json)
		let entry = ResearchEntry(date: .now, items: demoItems)
		let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
		completion(Timeline(entries: [entry], policy: .after(next)))
	}

	private var demoItems: [ResearchItemLite] {
		[
			.init(id: "r1", title: "US Banks: Capital markets rebound drives EPS beats", teaser: "3Q preview: FICC normalization vs ECM recovery.", deeplink: URL(string: "markets://research/r1"), ts: .now),
			.init(id: "r2", title: "Semis: AI accelerator demand outlook 2026+", teaser: "Supply chain checks point to cooling GPU lead times.", deeplink: URL(string: "markets://research/r2"), ts: .now),
			.init(id: "r3", title: "Energy: Brent at $85—positioning and risks", teaser: "OPEC+ discipline offsets non-OPEC growth.", deeplink: URL(string: "markets://research/r3"), ts: .now)
		]
	}
}

// MARK: - View
struct ResearchWidgetView: View {
	let entry: ResearchEntry

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(entry.items.prefix(3), id: \.id) { item in
				// Per-row deep link using Link is supported in widgets on recent iOS,
				// but .widgetURL at root is the broadest-compatible. We’ll use Link here.
				if let url = item.deeplink {
					Link(destination: url) {
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
					}
				} else {
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
				}
				if item.id != entry.items.prefix(3).last?.id { Divider() }
			}
			HStack {
				Image(systemName: "lock")
				Text("Lock Screen privacy supported")
				Spacer()
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
		.privacySensitive()
		.padding(8)
	}
}

// MARK: - Widget
struct ResearchWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "com.gs.marquee.research",
							provider: ResearchProvider()) { entry in
			ResearchWidgetView(entry: entry)
		}
		.configurationDisplayName("Marquee Research")
		.description("Latest research you follow.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
	}
}

#Preview(as: .systemMedium) {
	ResearchWidget()
} timeline: {
	ResearchEntry(date: .now, items: [
		.init(id: "r1", title: "Preview Headline", teaser: "Short teaser goes here.", deeplink: nil, ts: .now),
		.init(id: "r2", title: "Another Preview Headline", teaser: "Teaser 2", deeplink: nil, ts: .now),
		.init(id: "r3", title: "Third Headline", teaser: "Teaser 3", deeplink: nil, ts: .now),
	])
}
