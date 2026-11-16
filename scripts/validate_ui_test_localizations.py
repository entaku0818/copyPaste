#!/usr/bin/env python3
"""Keep the explicit UI launch matrix aligned with the app's bundled languages."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate the fixture")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    app = root / "ios/copyPaste"
    fixture = root / "ios/copyPasteUITests/LaunchTestLocalizations.json"
    languages = sorted(path.stem for path in app.glob("*.lproj") if path.stem != "Base")
    if not languages:
        raise SystemExit("No app localizations found")
    if args.write:
        fixture.write_text(json.dumps(languages, indent=2) + "\n")
    actual = json.loads(fixture.read_text())
    if actual != languages:
        raise SystemExit(
            "UI launch localizations differ from the app. Run "
            "python3 scripts/validate_ui_test_localizations.py --write and review the diff."
        )
    print(f"UI launch matrix covers all {len(languages)} app localizations.")


if __name__ == "__main__":
    main()
