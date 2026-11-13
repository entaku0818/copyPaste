#!/usr/bin/env python3
"""Validate ClipKit localization coverage against LOCALIZATION_PROGRESS.md.

By default, checks locales marked Complete in the progress table. Pass --all
once the rollout is complete to require all 50 App Store locale bundles.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = (
    "ar", "bn", "ca", "zh-Hans", "zh-Hant", "hr", "cs", "da", "nl-NL",
    "en-AU", "en-CA", "en-GB", "en-US", "fi", "fr-FR", "fr-CA", "de-DE",
    "el", "gu", "he", "hi", "hu", "id", "it", "ja", "kn", "ko", "ms",
    "ml", "mr", "no", "or", "pl", "pt-BR", "pt-PT", "pa", "ro", "ru",
    "sk", "sl", "es-MX", "es-ES", "sv", "ta", "te", "th", "tr", "uk",
    "ur", "vi",
)
LANGUAGE_GROUPS = {locale.split("-")[0] for locale in LOCALES}
if len(LOCALES) != 50 or len(LANGUAGE_GROUPS) != 43:
    raise RuntimeError("Expected 50 App Store locales across 43 language groups")

# App Store Connect uses regional shortcodes for several metadata localizations.
# In-app .lproj folders intentionally keep the device language identifiers above.
ASC_METADATA_LOCALE = {
    "ar": "ar-SA", "bn": "bn-BD", "gu": "gu-IN", "kn": "kn-IN",
    "ml": "ml-IN", "mr": "mr-IN", "or": "or-IN", "pa": "pa-IN",
    "sl": "sl-SI", "ta": "ta-IN", "te": "te-IN", "ur": "ur-PK",
}

TARGETS = ("copyPaste", "ClipboardKeyboard", "ClipboardWidget")
METADATA_FILES = (
    "name.txt", "subtitle.txt", "description.txt", "keywords.txt",
    "release_notes.txt", "marketing_url.txt", "privacy_url.txt", "support_url.txt",
)
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "description.txt": 4000,
    "keywords.txt": 100,
    "release_notes.txt": 4000,
}
STRINGS_ENTRY = re.compile(
    r'^\s*"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;',
    re.MULTILINE,
)
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:@|d|lld|f)")
PROGRESS_ROW = re.compile(r"^\|\s*([^|]+)\|\s*[^|]+\|\s*([^|]+)\|", re.MULTILINE)


def parse_strings(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    entries = STRINGS_ENTRY.findall(text)
    values = dict(entries)
    if len(values) != len(entries):
        raise ValueError(f"{path}: duplicate key")
    return values


def completed_locales() -> set[str]:
    progress = (ROOT / "LOCALIZATION_PROGRESS.md").read_text(encoding="utf-8")
    return {
        match.group(1).strip()
        for match in PROGRESS_ROW.finditer(progress)
        if match.group(2).strip() == "Complete"
    }


def project_regions() -> set[str]:
    text = (ROOT / "ios" / "copyPaste.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    match = re.search(r"knownRegions\s*=\s*\((.*?)\);", text, re.DOTALL)
    if not match:
        raise ValueError("project.pbxproj: knownRegions block not found")
    return {item.strip().strip(',').strip('"') for item in match.group(1).splitlines() if item.strip().strip(',')}


def validate_locale(locale: str) -> list[str]:
    errors: list[str] = []
    for target in TARGETS:
        base_path = ROOT / "ios" / target / "en.lproj" / "Localizable.strings"
        locale_path = ROOT / "ios" / target / f"{locale}.lproj" / "Localizable.strings"
        if not locale_path.exists():
            errors.append(f"{target}: missing {locale_path.relative_to(ROOT)}")
            continue
        try:
            base = parse_strings(base_path)
            current = parse_strings(locale_path)
        except (OSError, ValueError) as exc:
            errors.append(str(exc))
            continue
        missing = sorted(base.keys() - current.keys())
        extra = sorted(current.keys() - base.keys())
        if missing:
            errors.append(f"{target}: {len(missing)} missing keys: {', '.join(missing[:5])}")
        if extra:
            errors.append(f"{target}: {len(extra)} extra keys: {', '.join(extra[:5])}")
        for key in base.keys() & current.keys():
            if sorted(PLACEHOLDER.findall(base[key])) != sorted(PLACEHOLDER.findall(current[key])):
                errors.append(f"{target}: placeholder mismatch for {key}")
            if not current[key].strip():
                errors.append(f"{target}: empty value for {key}")

    info = ROOT / "ios" / "copyPaste" / f"{locale}.lproj" / "InfoPlist.strings"
    if not info.exists():
        errors.append("copyPaste: missing InfoPlist.strings")
    else:
        try:
            info_values = parse_strings(info)
            if not info_values.get("NSPasteboardUsageDescription", "").strip():
                errors.append("copyPaste: missing NSPasteboardUsageDescription")
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    metadata_locale = ASC_METADATA_LOCALE.get(locale, locale)
    metadata_dir = ROOT / "fastlane" / "metadata" / metadata_locale
    for filename in METADATA_FILES:
        path = metadata_dir / filename
        if not path.exists():
            errors.append(f"metadata: missing {metadata_locale}/{filename}")
            continue
        value = path.read_text(encoding="utf-8").strip()
        if not value:
            errors.append(f"metadata: empty {metadata_locale}/{filename}")
        limit = LIMITS.get(filename)
        if limit and len(value) > limit:
            errors.append(f"metadata: {metadata_locale}/{filename} is {len(value)} chars (limit {limit})")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="require and validate all 50 locales")
    args = parser.parse_args()

    completed = completed_locales()
    if args.all:
        targets = set(LOCALES)
    else:
        targets = completed & set(LOCALES)

    errors: list[str] = []
    missing_regions = sorted(set(LOCALES) - project_regions())
    if missing_regions:
        errors.append("project.pbxproj missing knownRegions: " + ", ".join(missing_regions))
    expected_metadata = {ASC_METADATA_LOCALE.get(locale, locale) for locale in LOCALES}
    actual_metadata = {
        path.name for path in (ROOT / "fastlane" / "metadata").iterdir()
        if path.is_dir() and (path / "name.txt").is_file()
    }
    if expected_metadata != actual_metadata:
        errors.append(
            "Fastlane metadata locale directories differ from Apple's 50 shortcodes; "
            f"missing={sorted(expected_metadata - actual_metadata)}, "
            f"unexpected={sorted(actual_metadata - expected_metadata)}"
        )
    for locale in sorted(targets):
        locale_errors = validate_locale(locale)
        if locale_errors:
            errors.extend(f"{locale}: {error}" for error in locale_errors)

    print(f"Complete locales checked: {len(targets)}/{len(LOCALES)} ({len(LANGUAGE_GROUPS)} language groups)")
    print(f"Xcode knownRegions: {len(LOCALES) - len(missing_regions)}/{len(LOCALES)}")
    print(f"Fastlane metadata locales: {len(actual_metadata & expected_metadata)}/{len(expected_metadata)}")
    if args.all:
        missing_status = sorted(set(LOCALES) - completed)
        if missing_status:
            errors.append(f"Progress table still has {len(missing_status)} incomplete locales: {', '.join(missing_status)}")
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors))
        return 1
    print("All checked localization keys, format placeholders, InfoPlist values, and metadata limits are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
