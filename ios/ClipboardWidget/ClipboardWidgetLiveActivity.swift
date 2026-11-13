//
//  ClipboardWidgetLiveActivity.swift
//  ClipboardWidget
//
//  Created by 遠藤拓弥 on 2026/02/13.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClipboardWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClipboardWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClipboardWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("liveActivity.greeting") + Text(" \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("liveActivity.leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("liveActivity.trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("liveActivity.bottom") + Text(" \(context.state.emoji)")
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

extension ClipboardWidgetAttributes {
    fileprivate static var preview: ClipboardWidgetAttributes {
        ClipboardWidgetAttributes(name: "World")
    }
}

extension ClipboardWidgetAttributes.ContentState {
    fileprivate static var smiley: ClipboardWidgetAttributes.ContentState {
        ClipboardWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClipboardWidgetAttributes.ContentState {
         ClipboardWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClipboardWidgetAttributes.preview) {
   ClipboardWidgetLiveActivity()
} contentStates: {
    ClipboardWidgetAttributes.ContentState.smiley
    ClipboardWidgetAttributes.ContentState.starEyes
}
