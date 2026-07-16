## Context

CastNow currently maintains a dual-language (en/zh) i18n system:
- **Web**: `vue-i18n` with `locales/en.json` and `locales/zh.json`, language toggle in App.vue, locale detection in `i18n.js`
- **Flutter**: Custom `AppLocalizations` base class with `_isZh` conditional logic, separate `app_localizations_en.dart` and `app_localizations_zh.dart`, `.arb` files

The 6-digit pairing code generation uses `Math.floor(100000 + Math.random() * 900000)` in Web and `(100000 + rng.nextInt(900000)).toString()` in Flutter. Validation checks `code.length != 6`.

The cloud signaling service (PeerJS) treats the code as an opaque string — length is irrelevant to the protocol. The code is used only as a PeerJS peer ID prefix (`castnow_<code>_<device>`), which imposes no length constraint.

## Goals / Non-Goals

**Goals:**
- Remove all Chinese localization assets, code, and dependencies
- Replace dynamic i18n with static English strings throughout both platforms
- Keep pairing code at 6 digits — easier for users to remember and share, sufficient entropy for ephemeral sessions

**Non-Goals:**
- Adding any new language support
- Changing the signaling protocol or PeerJS peer ID format
- Modifying RTMP streaming logic
- Changing subscription/paywall flow

## Decisions

### D1: Web i18n — Remove vue-i18n, use plain English strings

**Choice**: Delete `vue-i18n` dependency, replace all `$t('key')` / `t('key')` calls with literal English strings.

**Alternatives considered**:
- Keep vue-i18n with only `en` locale: adds unnecessary dependency weight (~3KB gzipped) and complicates code
- Use a simple `const strings = {...}` module: still adds indirection without benefit

**Rationale**: With only one language, i18n is pure overhead. Plain strings are the simplest, most debuggable approach.

### D2: Flutter i18n — Collapse AppLocalizations to a flat constants file

**Choice**: Replace `AppLocalizations` class with a simple Dart file exporting `const String` values (e.g., `appStrings.dart`). Remove `flutter_localizations` dependency.

**Alternatives considered**:
- Keep `AppLocalizations` but remove `_isZh`: still requires `BuildContext` and delegate wiring
- Use `.arb` single-locale gen-l10n: overkill for one language

**Rationale**: Static constants eliminate runtime overhead, widget tree dependency, and delegate boilerplate. Direct string references are the Flutter idiomatic approach for single-language apps.

### D3: 6-digit code — Keep current range, no protocol impact

**Choice**: Keep generation range at [100000, 999999]. 6 digits are easier to read, remember, and share verbally while providing 900K valid codes — more than sufficient for ephemeral P2P sessions.

**Alternatives considered**:
- 8-digit codes: more entropy but harder to remember and communicate
- Alphanumeric codes: even more entropy but much harder to type/remember

**Rationale**: PeerJS treats the code as an opaque peer ID component. 6 digits provides ample collision resistance for the expected concurrent usage. User experience (easy to share verbally) outweighs the marginal security benefit of additional digits.

### D4: iPhone landscape layout — Responsive digit sizing

**Choice**: Use flexible digit cell sizing with `Expanded`/`Flexible` in Flutter and CSS grid with `minmax()` in Web. Target minimum 36px tap target per digit on mobile.

**Alternatives considered**:
- Fixed-width digits: breaks on narrow screens
- Scrollable input: poor UX for code entry

**Rationale**: 6 digits at 48px each = 288px minimum, plus gaps ≈ 340px. iPhone SE portrait (375px) fits comfortably. Landscape orientation provides even more room.

## Risks / Trade-offs

- **[Risk] Removing vue-i18n breaks existing references**: Mitigation — systematic grep-and-replace across all .vue/.js files; verify via `npm run build`
- **[Risk] Flutter AppLocalizations refactor breaks widgets**: Mitigation — use `const` strings; Flutter hot reload catches issues immediately
- **[Risk] 6-digit layout on very small screens**: Mitigation — responsive sizing with `Expanded`; 6 digits fit easily on all iPhones including SE portrait (375px)
- **[Risk] Existing saved codes (in SharedPreferences/localStorage) are 6-digit**: Mitigation — codes are ephemeral (session-only), no migration needed

## Open Questions

- None — all decisions are straightforward and non-breaking for the signaling layer
