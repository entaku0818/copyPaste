//
//  copyPasteUITestsLaunchTests.swift
//  copyPasteUITests
//
//  Created by 遠藤拓弥 on 2025/05/02.
//

import XCTest

final class ClipKitUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        // Xcode 27.1's automatic variation expansion grows exponentially with
        // multiple axes (53 languages trigger a runner crash before any test).
        // Enumerate every supported configuration explicitly, in linear space.
        let resource = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "LaunchTestLocalizations", withExtension: "json"
        ))
        let languages = try JSONDecoder().decode([String].self, from: Data(contentsOf: resource))
        XCTAssertFalse(languages.isEmpty)

        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        let originalOrientation = device.orientation
        defer {
            device.appearance = originalAppearance
            device.orientation = originalOrientation
        }

        var orientations: [(String, UIDeviceOrientation)] = [
            ("portrait", .portrait),
            ("landscapeLeft", .landscapeLeft),
            ("landscapeRight", .landscapeRight)
        ]
        if UIDevice.current.userInterfaceIdiom == .pad {
            orientations.append(("portraitUpsideDown", .portraitUpsideDown))
        }
        let appearances: [(String, XCUIDevice.Appearance)] = [("light", .light), ("dark", .dark)]
        let app = XCUIApplication()
        defer { app.terminate() }
        var completedConfigurations = 0

        for language in languages {
            for (appearanceName, appearance) in appearances {
                device.appearance = appearance
                device.orientation = .portrait
                app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
                app.launch()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), language)

                for (orientationName, orientation) in orientations {
                    XCTContext.runActivity(named: "\(language)-\(appearanceName)-\(orientationName)") { _ in
                        device.orientation = orientation
                        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
                        let attachment = XCTAttachment(screenshot: app.screenshot())
                        attachment.name = "Launch-\(language)-\(appearanceName)-\(orientationName)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                        completedConfigurations += 1
                    }
                }
                app.terminate()
            }
        }

        let expectedConfigurations = languages.count * appearances.count * orientations.count
        XCTAssertEqual(completedConfigurations, expectedConfigurations)
        let coverage = "Launch matrix completed: \(completedConfigurations) configurations; "
            + "\(languages.count) languages x \(appearances.count) appearances x \(orientations.count) orientations"
        print(coverage)

        let attachment = XCTAttachment(string: coverage + "\nLanguages: " + languages.joined(separator: ", "))
        attachment.name = "Launch matrix coverage"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
