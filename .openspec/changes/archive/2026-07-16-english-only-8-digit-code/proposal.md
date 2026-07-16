## Why

CastNow currently maintains full Chinese localization (i18n) across Web and Flutter, despite having no Chinese-speaking user base. This adds unnecessary complexity to every UI change, bloats the codebase with duplicate string definitions, and complicates testing. The 6-digit pairing code (1M combinations) provides sufficient entropy for the ephemeral pairing use case and is easier for users to remember and share.

## What Changes

- **BREAKING**: Remove all Chinese (zh) localization — Web `locales/zh.json`, Flutter `app_localizations_zh.dart`, `app_zh.arb`, and all `_isZh` conditional branches
- Simplify Flutter `AppLocalizations` to English-only (no locale parameter, no delegate complexity)
- Remove `vue-i18n` dependency from Web; replace `$t()` / `useI18n()` with plain English strings
- Remove language toggle UI from Web App.vue
- Update `privacy.html`, `terms.html` to English-only
- Update `README.md` to remove Chinese references
- Keep pairing code at 6-digit across Web and Flutter (easier to remember and share)
- Confirmed code input UI layout (Flutter + Web) fits 6 digits across all orientations
- Update all user-facing strings to use consistent "6-digit code" terminology

## Capabilities

### New Capabilities

- `english-only-localization`: Remove all Chinese language support and i18n infrastructure, simplifying the app to English-only across Web and Flutter platforms
- `6-digit-pairing-code`: Confirmed 6-digit pairing code across all platforms — easier to remember and share while providing sufficient entropy for ephemeral sessions

### Modified Capabilities

<!-- No existing specs to modify -->

## Impact

- **Web**: `App.vue`, `i18n.js`, `i18n.test.js`, `main.js`, `locales/`, `composables/useMediaStream.js`, `composables/useWebRTC.js`, `components/ReceiverView.vue`, `components/InfoModal.vue`, `privacy.html`, `terms.html`, `package.json` (remove vue-i18n dep)
- **Flutter**: `lib/l10n/` (all files), `lib/screens/broadcast_screen.dart`, `lib/screens/receive_screen.dart`, `lib/screens/home_screen.dart`, `lib/services/media_capture_service.dart`, `lib/widgets/code_display.dart`, `lib/widgets/paywall_dialog.dart`, `lib/main.dart`
- **Docs**: `README.md`
- **Dependencies removed**: `vue-i18n` (npm), `flutter_localizations` (pub — if no longer needed for other reasons)
