## ADDED Requirements

### Requirement: Code generation produces 6-digit codes
The system SHALL generate random 6-digit numeric pairing codes in the range [100000, 999999] inclusive.

#### Scenario: Web generates valid 6-digit code
- **WHEN** the Web app calls code generation
- **THEN** the result is a 6-character string consisting only of digits, with value ≥ 100000 and ≤ 999999

#### Scenario: Flutter generates valid 6-digit code
- **WHEN** the Flutter app calls `MediaCaptureService.generateCode()`
- **THEN** the result is a 6-character string consisting only of digits, with value ≥ 100000 and ≤ 999999

### Requirement: Code input validates 6-digit length
The pairing code input field SHALL accept exactly 6 digits and SHALL reject codes of any other length.

#### Scenario: Receiver accepts valid 6-digit code
- **WHEN** a user enters exactly 6 numeric digits in the code input field and submits
- **THEN** the system proceeds with connection

#### Scenario: Receiver rejects incomplete code
- **WHEN** a user enters fewer than 6 digits and attempts to submit
- **THEN** the system does not initiate connection and shows a validation hint

#### Scenario: Receiver rejects excess digits
- **WHEN** a user attempts to enter more than 6 digits
- **THEN** the input field prevents additional characters

### Requirement: Code display accommodates 6 digits
The code display UI (broadcast screen) SHALL render all 6 digits legibly on all supported screen sizes, including iPhone portrait (375pt width) and landscape orientation.

#### Scenario: 6-digit code displays correctly on iPhone portrait
- **WHEN** the broadcast screen shows a 6-digit pairing code on iPhone in portrait mode
- **THEN** all 6 digits are fully visible, evenly spaced, with no truncation or overflow

#### Scenario: 6-digit code displays correctly on iPhone landscape
- **WHEN** the broadcast screen shows a 6-digit pairing code on iPhone in landscape mode
- **THEN** all 6 digits are fully visible with comfortable spacing, no digit wrapping

### Requirement: User-facing text reflects 6-digit code
All UI strings referencing the pairing code length SHALL state "6-digit".

#### Scenario: Web UI shows 6-digit prompt
- **WHEN** a user views the code entry screen on Web
- **THEN** the placeholder or label text references "6-digit code"

#### Scenario: Flutter UI shows 6-digit prompt
- **WHEN** a user views the code entry screen on Flutter
- **THEN** the placeholder or label text references "6-digit code"

### Requirement: Signaling protocol remains unchanged
The PeerJS signaling protocol SHALL continue to use the pairing code as an opaque peer ID component without modification to the message format or handshake logic.

#### Scenario: Peer ID construction uses pairing code
- **WHEN** a broadcaster establishes a PeerJS connection
- **THEN** the peer ID is constructed as `castnow_<code>_<device-info>` without any protocol changes

## REMOVED Requirements

### Requirement: 8-digit pairing code upgrade
**Reason**: 8-digit codes were briefly implemented but reverted — 6-digit codes are easier for users to remember and share verbally while providing sufficient entropy for ephemeral P2P sessions.
**Migration**: All 8-digit references have been reverted to 6-digit across code, docs, and blog posts.
