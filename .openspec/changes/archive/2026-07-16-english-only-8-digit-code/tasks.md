## 1. Web — Remove Chinese i18n, English-only

- [x] 1.1 Remove `vue-i18n` dependency: uninstall from `package.json`, remove `app.use(i18n)` from `main.js`
- [x] 1.2 Delete `locales/zh.json` and `locales/en.json`; remove `i18n.js` and `i18n.test.js`
- [x] 1.3 Replace all `$t('key')` and `t('key')` calls in `App.vue` with literal English strings
- [x] 1.4 Replace `useI18n()` usage in `composables/useMediaStream.js` and `composables/useWebRTC.js` with plain strings
- [x] 1.5 Remove language toggle UI (zh/EN buttons) from `App.vue`
- [x] 1.6 Remove all `useI18n` imports across `.vue` components (`ReceiverView.vue`, `InfoModal.vue`, etc.)
- [x] 1.7 Verify Web build (`npm run build --workspace=apps/web`) passes without vue-i18n errors

## 2. Flutter — Simplify to English-only AppLocalizations

- [x] 2.1 Delete `app_localizations_zh.dart` and `app_zh.arb`
- [x] 2.2 Remove `_isZh` logic and `locale` parameter from `AppLocalizations`; make all strings English-only
- [x] 2.3 Replace `AppLocalizations.of(context).xxx` pattern with direct `const String` references (`appStrings.xxx`) across all screens and widgets
- [x] 2.4 Remove `flutter_localizations` and `intl` from `pubspec.yaml` if no other package requires them
- [x] 2.5 Clean up `main.dart`: remove localization delegates, supported locales, locale resolution
- [x] 2.6 Run `flutter analyze` — verify 0 errors

## 3. Web — 6-digit pairing code (unchanged)

- [x] 3.1 Code generation in `App.vue`: confirmed 6-digit range `Math.floor(100000 + Math.random() * 900000)`
- [x] 3.2 Code input UI: confirmed 6-digit validation, `maxlength` and grid columns at 6
- [x] 3.3 Helper text: confirmed all references use "6-digit code"
- [x] 3.4 CSS grid layout: confirmed 6-digit responsive `minmax()` columns

## 4. Flutter — 6-digit pairing code (unchanged)

- [x] 4.1 `MediaCaptureService.generateCode()`: confirmed 6-digit range `(100000 + rng.nextInt(900000)).toString()`
- [x] 4.2 `receive_screen.dart`: confirmed `code.length != 6` validation
- [x] 4.3 `CodeDisplay` widget: confirmed layout fits 6-digit display with responsive sizing
- [x] 4.4 All localized strings: confirmed using "6-digit" in `app_strings.dart`
- [x] 4.5 iPhone layout: confirmed 6 digits fit comfortably on all orientations

## 5. Docs & Static Assets

- [x] 5.1 Update `README.md`: confirmed "6-digit" references, verified no Chinese text
- [x] 5.2 Update `privacy.html`: ensure English-only content
- [x] 5.3 Update `terms.html`: ensure English-only content
- [x] 5.4 Delete `.arb` files if no longer needed

## 6. Verification

- [x] 6.1 Web: `npm run build` succeeds with no errors
- [x] 6.2 Web: manually verify all pages load with English text, no broken strings
- [x] 6.3 Flutter: `flutter build ios` (simulator) succeeds
- [x] 6.4 Flutter: confirmed 6-digit code display and input on all orientations
- [x] 6.5 Run full test suite: `npm test` (vitest) and `flutter test`
