#!/usr/bin/env python3
"""
App Store screenshot framing script.
Composites raw screenshots into the existing style (01.png reference).
"""

from PIL import Image, ImageDraw, ImageFont
import numpy as np
import sys

FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc"

IPHONE_CONFIG = {
    "canvas_size": (1320, 2868),
    "screen_rect": (124, 449, 1196, 2867),   # x1, y1, x2, y2 (measured from 01.png reference)
    "caption_center_y": 270,
    "caption_font_size": 120,
    "caption_line_spacing": 140,
    "bg_color": (8, 19, 17),
}

IPAD_CONFIG = {
    "canvas_size": (2064, 2752),
    "screen_rect": (195, 461, 1869, 2751),   # x1, y1, x2, y2 (measured from 01.png reference)
    "caption_center_y": 290,
    "caption_font_size": 160,
    "caption_line_spacing": 190,
    "bg_color": (8, 19, 17),
}


def frame_screenshot(raw_path: str, template_path: str, output_path: str,
                     caption: str, config: dict) -> None:
    template = Image.open(template_path).convert("RGBA")
    raw = Image.open(raw_path).convert("RGBA")

    x1, y1, x2, y2 = config["screen_rect"]
    screen_w = x2 - x1
    screen_h = y2 - y1

    # Scale raw screenshot to fit screen area
    raw_resized = raw.resize((screen_w, screen_h), Image.LANCZOS)

    # Paste raw screenshot into template at screen position
    result = template.copy()
    result.paste(raw_resized, (x1, y1))

    # Clear caption area with background color (y=0 to y1)
    draw = ImageDraw.Draw(result)
    bg = config["bg_color"]
    draw.rectangle([(0, 0), (config["canvas_size"][0], y1)], fill=bg + (255,))

    # Restore subtle glow: radial gradient in caption area
    canvas_w, canvas_h = config["canvas_size"]
    glow_cx = canvas_w // 2
    glow_cy = y1 // 2
    glow_r = min(canvas_w, y1) * 0.8
    arr = np.array(result).astype(np.float32)
    for y in range(0, y1):
        for x in range(0, canvas_w, 4):  # sample every 4px for speed
            dist = ((x - glow_cx)**2 + (y - glow_cy)**2) ** 0.5
            factor = max(0.0, 1.0 - dist / glow_r) * 0.15
            arr[y, x:x+4, 1] = np.clip(arr[y, x:x+4, 1] + factor * 120, 0, 255)
            arr[y, x:x+4, 0] = np.clip(arr[y, x:x+4, 0] + factor * 40, 0, 255)
    result = Image.fromarray(arr.astype(np.uint8))
    draw = ImageDraw.Draw(result)

    # Draw caption text (white, centered)
    font = ImageFont.truetype(FONT_PATH, config["caption_font_size"])
    lines = caption.split("\n")
    line_h = config["caption_line_spacing"]
    total_h = line_h * len(lines)
    start_y = config["caption_center_y"] - total_h // 2

    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        text_w = bbox[2] - bbox[0]
        text_x = (canvas_w - text_w) // 2
        text_y = start_y + i * line_h
        # subtle shadow
        draw.text((text_x + 2, text_y + 2), line, font=font, fill=(0, 0, 0, 100))
        draw.text((text_x, text_y), line, font=font, fill=(255, 255, 255, 255))

    result = result.convert("RGB")
    result.save(output_path, "PNG")
    print(f"Saved: {output_path}")


if __name__ == "__main__":
    base = "/Users/entaku/repository/copyPaste/fastlane/screenshots/ja-JP"

    # iPhone 03.png: Widget
    frame_screenshot(
        raw_path="/tmp/widget_iphone_raw.png",
        template_path=f"{base}/iPhones  6.9/01.png",
        output_path=f"{base}/iPhones  6.9/03.png",
        caption="ホーム画面に、\nクリップボードを",
        config=IPHONE_CONFIG,
    )

    # iPad 03.png: Widget
    frame_screenshot(
        raw_path="/tmp/widget_ipad_raw.png",
        template_path=f"{base}/iPad  13/01.png",
        output_path=f"{base}/iPad  13/03.png",
        caption="ホーム画面に、\nクリップボードを",
        config=IPAD_CONFIG,
    )

    # iPad 02.png: Keyboard (keep for reference)
    frame_screenshot(
        raw_path=f"{base}/iPad  13/02.png",
        template_path=f"{base}/iPad  13/01.png",
        output_path="/tmp/ipad_02_framed.png",
        caption="キーボードから\nそのまま貼り付け",
        config=IPAD_CONFIG,
    )
