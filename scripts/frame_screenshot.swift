#!/usr/bin/env swift
// App Store screenshot framing — macOS only, no external dependencies
// Usage: swift scripts/frame_screenshot.swift
import AppKit

struct FrameConfig {
    let canvasSize: NSSize
    let screenRect: NSRect      // top-left origin
    let captionAreaHeight: CGFloat
    let captionCenterY: CGFloat  // center of caption text block, from top
    let captionFontSize: CGFloat
    let captionLineSpacing: CGFloat
}

let iPhoneConfig = FrameConfig(
    canvasSize: NSSize(width: 1320, height: 2868),
    screenRect: NSRect(x: 124, y: 449, width: 1072, height: 2418),
    captionAreaHeight: 449,
    captionCenterY: 270,
    captionFontSize: 120,
    captionLineSpacing: 140
)

let iPadConfig = FrameConfig(
    canvasSize: NSSize(width: 2064, height: 2752),
    screenRect: NSRect(x: 195, y: 461, width: 1674, height: 2290),
    captionAreaHeight: 461,
    captionCenterY: 290,
    captionFontSize: 160,
    captionLineSpacing: 190
)

func frameScreenshot(
    rawPath: String,
    templatePath: String,
    outputPath: String,
    caption: String,
    config: FrameConfig
) {
    guard let template = NSImage(contentsOfFile: templatePath) else {
        fputs("Error: cannot load template: \(templatePath)\n", stderr); exit(1)
    }
    guard let raw = NSImage(contentsOfFile: rawPath) else {
        fputs("Error: cannot load raw: \(rawPath)\n", stderr); exit(1)
    }

    let canvas = NSImage(size: config.canvasSize)
    canvas.lockFocusFlipped(true)  // top-left origin, y increases downward

    // 1. Draw template
    template.draw(in: NSRect(origin: .zero, size: config.canvasSize))

    // 2. Composite raw screenshot into screen area
    raw.draw(in: config.screenRect)

    // 3. Fill caption area with dark background
    NSColor(red: 8/255, green: 19/255, blue: 17/255, alpha: 1).setFill()
    NSBezierPath.fill(NSRect(x: 0, y: 0, width: config.canvasSize.width, height: config.captionAreaHeight))

    // 4. Subtle radial glow
    let glowCenter = NSPoint(x: config.canvasSize.width / 2, y: config.captionCenterY)
    let glowRadius = min(config.canvasSize.width, config.captionAreaHeight) * 0.85
    NSGradient(
        colors: [NSColor(red: 0, green: 0.6, blue: 0.45, alpha: 0.12), .clear],
        atLocations: [0, 1],
        colorSpace: .genericRGB
    )?.draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: glowRadius, options: [])

    // 5. Draw caption text
    let font = NSFont(name: "HiraginoSans-W7", size: config.captionFontSize)
            ?? NSFont.boldSystemFont(ofSize: config.captionFontSize)
    let lines = caption.components(separatedBy: "\n")
    let totalHeight = config.captionLineSpacing * CGFloat(lines.count)
    var lineY = config.captionCenterY - totalHeight / 2

    for line in lines {
        let str = NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: NSColor.white])
        let shadow = NSAttributedString(string: line, attributes: [
            .font: font,
            .foregroundColor: NSColor(white: 0, alpha: 0.5)
        ])
        let textX = (config.canvasSize.width - str.size().width) / 2
        shadow.draw(at: NSPoint(x: textX + 2, y: lineY + 2))
        str.draw(at: NSPoint(x: textX, y: lineY))
        lineY += config.captionLineSpacing
    }

    canvas.unlockFocus()

    // Save as PNG
    guard let tiff = canvas.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("Error: failed to render PNG\n", stderr); exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
        print("Saved: \(outputPath)")
    } catch {
        fputs("Error saving \(outputPath): \(error)\n", stderr); exit(1)
    }
}

// MARK: - Targets

let base = "/Users/entaku/repository/copyPaste/fastlane/screenshots/ja-JP"

frameScreenshot(
    rawPath: "/tmp/widget_iphone_raw.png",
    templatePath: "\(base)/iPhones  6.9/01.png",
    outputPath:   "\(base)/iPhones  6.9/03.png",
    caption: "ホーム画面に、\nクリップボードを",
    config: iPhoneConfig
)

frameScreenshot(
    rawPath: "/tmp/widget_ipad_raw.png",
    templatePath: "\(base)/iPad  13/01.png",
    outputPath:   "\(base)/iPad  13/03.png",
    caption: "ホーム画面に、\nクリップボードを",
    config: iPadConfig
)
