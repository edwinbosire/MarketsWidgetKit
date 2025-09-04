//
//  MarketWidgetsLiveActivity.swift
//  MarketWidgets
//
//  Created by Edwin Bosire on 04/09/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MarketWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MarketWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MarketWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MarketWidgetsAttributes {
    fileprivate static var preview: MarketWidgetsAttributes {
        MarketWidgetsAttributes(name: "World")
    }
}

extension MarketWidgetsAttributes.ContentState {
    fileprivate static var smiley: MarketWidgetsAttributes.ContentState {
        MarketWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MarketWidgetsAttributes.ContentState {
         MarketWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MarketWidgetsAttributes.preview) {
   MarketWidgetsLiveActivity()
} contentStates: {
    MarketWidgetsAttributes.ContentState.smiley
    MarketWidgetsAttributes.ContentState.starEyes
}
