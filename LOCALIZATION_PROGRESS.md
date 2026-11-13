# ClipKit localization rollout

Updated: 2026-11-08

## Scope and counting

Apple currently lists 50 App Store Connect localization slots. These represent 43 language groups: English (4 regional locales), French (2), Portuguese (2), Spanish (2), and Chinese (Simplified/Traditional script variants) account for the locale variants; the other languages each have one listed locale. The app will ship matching locale-tagged `.lproj` resources for all 50 slots, including regional wording where it matters.

Each locale is complete only when it has:

- 240 app `Localizable.strings` keys and localized clipboard permission text in `InfoPlist.strings`.
- 27 keyboard extension keys and 20 widget extension keys.
- App Store metadata: name, subtitle, description, keywords, release notes, marketing URL, privacy URL, and support URL.
- Matching keys and format placeholders, plus store field length checks.

App UI resource folders use the device language tags. Fastlane metadata uses Apple's exact 50 shortcodes; these 12 differ: `ar-SA`, `bn-BD`, `gu-IN`, `kn-IN`, `ml-IN`, `mr-IN`, `or-IN`, `pa-IN`, `sl-SI`, `ta-IN`, `te-IN`, and `ur-PK` map respectively to UI tags `ar`, `bn`, `gu`, `kn`, `ml`, `mr`, `or`, `pa`, `sl`, `ta`, `te`, and `ur`.

No locale is counted complete merely because it has a metadata folder or because English was copied into it.

## Progress

Current count: 50/50 App Store locales complete (43/43 language groups represented); 0 locales remain.

| App Store locale | Language/variant | Status | Owner |
| --- | --- | --- | --- |
| ar | Arabic | Complete | locale_europe |
| bn | Bangla | Complete | locale_asia |
| ca | Catalan | Complete | locale_west |
| zh-Hans | Chinese, Simplified | Complete | locale_asia |
| zh-Hant | Chinese, Traditional | Complete | locale_asia |
| hr | Croatian | Complete | locale_europe |
| cs | Czech | Complete | locale_europe |
| da | Danish | Complete | locale_europe |
| nl-NL | Dutch | Complete | locale_west |
| en-AU | English, Australia | Complete | root |
| en-CA | English, Canada | Complete | root |
| en-GB | English, U.K. | Complete | root |
| en-US | English, U.S. | Complete | existing |
| fi | Finnish | Complete | locale_europe |
| fr-FR | French | Complete | locale_west |
| fr-CA | French, Canada | Complete | locale_west |
| de-DE | German | Complete | locale_west |
| el | Greek | Complete | locale_europe |
| gu | Gujarati | Complete | locale_asia |
| he | Hebrew | Complete | locale_europe |
| hi | Hindi | Complete | locale_asia |
| hu | Hungarian | Complete | locale_west |
| id | Indonesian | Complete | locale_asia |
| it | Italian | Complete | locale_west |
| ja | Japanese | Complete | existing |
| kn | Kannada | Complete | locale_asia |
| ko | Korean | Complete | locale_asia |
| ms | Malay | Complete | locale_asia |
| ml | Malayalam | Complete | locale_asia |
| mr | Marathi | Complete | locale_asia |
| no | Norwegian | Complete | locale_west |
| or | Odia | Complete | locale_asia |
| pl | Polish | Complete | locale_europe |
| pt-BR | Portuguese, Brazil | Complete | locale_west |
| pt-PT | Portuguese, Portugal | Complete | locale_west |
| pa | Punjabi | Complete | locale_west |
| ro | Romanian | Complete | locale_europe |
| ru | Russian | Complete | locale_europe |
| sk | Slovak | Complete | locale_west |
| sl | Slovenian | Complete | locale_west |
| es-MX | Spanish, Mexico | Complete | existing |
| es-ES | Spanish, Spain | Complete | locale_west |
| sv | Swedish | Complete | locale_west |
| ta | Tamil | Complete | locale_asia |
| te | Telugu | Complete | locale_asia |
| th | Thai | Complete | locale_asia |
| tr | Turkish | Complete | locale_europe |
| uk | Ukrainian | Complete | locale_europe |
| ur | Urdu | Complete | locale_asia → locale_europe rewrite |
| vi | Vietnamese | Complete | locale_asia |

## Verification notes

- Current audit follow-up: Resolved duplicate widget keys in ar/ru/uk/tr. Corrected metadata limits in id/ms/vi and the Thai format placeholder now pass the validator. All 50 locale rows are complete.

- Existing `en`, `ja`, and `es` resources are retained as fallback-compatible bundles while locale-tagged bundles are added.
- Keyboard extension now sets `primaryLanguage` from the host text field's active input mode (with the preferred system language as fallback); plist retains the required neutral `en` fallback.
- `python3 scripts/validate_localizations.py --all`: passed (50/50 locales, 43 language groups, 50/50 Xcode known regions and 50/50 exact Fastlane metadata shortcodes, keys/placeholders/metadata limits).
- `plutil -lint` passed on localized plist/string resources and the project file; `git diff --check` passed.
- iOS device build passed. Unit tests passed: 279 passed, 1 skipped. The full simulator test run had the same 279 passing and 1 skipped, but the UI test runner crashed before bootstrapping; no localization assertion failed.
- A duplicate Urdu edit briefly overwrote the Asia batch before it was finalized; the surviving Europe version was validated and is recorded in the `ur` row above.
- App Store Connect initially showed 38 version localizations because Fastlane expects the 12 regional shortcodes above. Renamed those metadata directories, uploaded again, and verified 50 version localizations through the App Store Connect API.
- Release: ClipKit 1.7.8 (build 44). Archive and App Store IPA export succeeded. Apple rejected the first IPA because the keyboard extension lacked required `PrimaryLanguage`; restored `en` as the plist fallback while retaining runtime input-language reporting. The corrected IPA uploaded and processed as `VALID`.
- After the 50-localization correction, Fastlane's automatic build selector incorrectly chose build 29. Stopped before submission, explicitly selected build 44, and submitted the version. App Store Connect API reports `WAITING_FOR_REVIEW`, build 44 `VALID`, release type `MANUAL`, and 50 localizations.
- App Store Connect browser visual confirmation is still pending account sign-in; API status is confirmed.
- No commit or push has been made.

## Source

Apple Developer, [App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations).
