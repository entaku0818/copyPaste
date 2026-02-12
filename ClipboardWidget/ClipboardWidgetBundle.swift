//
//  ClipboardWidgetBundle.swift
//  ClipboardWidget
//
//  Created by 遠藤拓弥 on 2026/02/13.
//

import WidgetKit
import SwiftUI

@main
struct ClipboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClipboardWidget()
        ClipboardWidgetControl()
        ClipboardWidgetLiveActivity()
    }
}
