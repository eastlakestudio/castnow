# english-only-localization Specification

## Purpose
TBD - created by archiving change english-only-8-digit-code. Update Purpose after archive.
## Requirements
### Requirement: App uses English-only UI strings
The Web and Flutter apps SHALL display all user-facing text in English only. No Chinese (zh) locale or translation strings SHALL exist in the codebase.

#### Scenario: Web app displays English text
- **WHEN** a user opens the CastNow web app
- **THEN** all labels, buttons, error messages, and info modals display English text

#### Scenario: Flutter app displays English text
- **WHEN** a user opens the CastNow iOS app
- **THEN** all labels, buttons, error messages, and dialogs display English text

### Requirement: No i18n dependency
The system SHALL NOT depend on any internationalization library (vue-i18n, flutter_localizations, intl) for string management.

#### Scenario: Web package.json excludes vue-i18n
- **WHEN** the web app builds
- **THEN** `vue-i18n` is not listed in `package.json` dependencies and is not imported in any source file

#### Scenario: Flutter pubspec excludes l10n dependencies
- **WHEN** the Flutter app builds
- **THEN** `flutter_localizations` and `intl` are removed from `pubspec.yaml` if no longer needed by other packages

### Requirement: No language toggle UI
The user interface SHALL NOT include any language switcher, locale selector, or bilingual toggle control.

#### Scenario: Web landing page has no language toggle
- **WHEN** a user views the CastNow web landing page
- **THEN** there is no language/locale toggle button in the UI

#### Scenario: Flutter home screen has no language toggle
- **WHEN** a user views the CastNow iOS home screen
- **THEN** there is no language/locale toggle control in the UI

### Requirement: Legal documents are English-only
The privacy policy (`privacy.html`) and terms of service (`terms.html`) SHALL contain only English content.

#### Scenario: Privacy page is English-only
- **WHEN** a user navigates to `/privacy.html`
- **THEN** all content is in English with no Chinese text

#### Scenario: Terms page is English-only
- **WHEN** a user navigates to `/terms.html`
- **THEN** all content is in English with no Chinese text

