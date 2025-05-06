//
//  copyPasteApp.swift
//  copyPaste
//
//  Created by 遠藤拓弥 on 2025/05/02.
//

import SwiftUI
import ComposableArchitecture

@main
struct copyPasteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(
                    initialState: ClipboardHistoryFeature.State()
                ) {
                    ClipboardHistoryFeature()
                }
            )
        }
    }
}
