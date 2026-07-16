## 新增需求

### 需求：首次免费试用时长
系统 SHALL 允许未订阅用户在设备首次使用时，进行连续 2 分钟的广播会话。试用状态 MUST 使用 `localStorage`（Web）或 `SharedPreferences`（Flutter）在键 `free_trial_used` 下按设备持久化。

#### 场景：全新设备首次广播
- **WHEN** 未订阅用户在一台没有 `free_trial_used` 标记的设备上启动广播
- **THEN** 系统 SHALL 启动 120 秒倒计时，且在计时器到期前 SHALL NOT 中断广播

#### 场景：试用到期中断广播
- **WHEN** 2 分钟倒计时在活跃广播期间归零
- **THEN** 系统 SHALL 弹出付费墙弹窗，若用户未在 10 秒内订阅则 SHALL 终止广播

### 需求：后续会话试用时长
系统 SHALL 将已使用过首次试用的未订阅用户，每次广播会话限制为最长 30 秒。

#### 场景：回访用户启动广播
- **WHEN** 一个 `free_trial_used` 标记已为 `true` 的未订阅用户启动新广播
- **THEN** 系统 SHALL 启动 30 秒倒计时

#### 场景：后续试用到期
- **WHEN** 30 秒倒计时在活跃广播期间归零
- **THEN** 系统 SHALL 立即弹出付费墙弹窗，若用户未在 5 秒内订阅则 SHALL 终止广播

### 需求：试用状态持久化
系统 SHALL 将试用状态持久化为布尔标记 `free_trial_used`。用户首次完成广播（无论被计时器终止还是手动停止）时，MUST 将该标记设为 `true`。该标记 NOT 因卸载/重装而清除（尽力而为的设备级持久化）。

#### 场景：首次广播后标记置位
- **WHEN** 未订阅用户停止或被超时终止首次广播会话
- **THEN** 系统 SHALL 将持久化存储中的 `free_trial_used` 设为 `true`

#### 场景：标记跨应用重启持久化
- **WHEN** 之前已完成一次广播的用户重新打开应用
- **THEN** `free_trial_used` 标记 SHALL 仍为 `true`，后续广播 SHALL 使用 30 秒限制

### 需求：已订阅用户绕过试用限制
系统 SHALL NOT 对拥有活跃 Pro 订阅的用户施加任何试用时长限制。

#### 场景：Pro 用户启动广播
- **WHEN** 已订阅用户启动广播
- **THEN** 系统 SHALL NOT 显示任何倒计时或时限警告
## ADDED Requirements

### Requirement: First-time free trial duration
The system SHALL allow an unsubscribed user to broadcast for a continuous 2-minute session on their first-ever use of the app. The trial state MUST be persisted per device using `localStorage` (Web) or `SharedPreferences` (Flutter) under the key `free_trial_used`.

#### Scenario: First broadcast on a fresh device
- **WHEN** an unsubscribed user starts a broadcast on a device that has no `free_trial_used` flag
- **THEN** the system SHALL start a 120-second countdown timer and SHALL NOT interrupt the broadcast before the timer expires

#### Scenario: Trial expiration during broadcast
- **WHEN** the 2-minute countdown reaches zero during an active broadcast
- **THEN** the system SHALL display a paywall dialog and SHALL terminate the broadcast within 10 seconds if the user does not subscribe

### Requirement: Subsequent session trial duration
The system SHALL limit unsubscribed users who have previously used their first-time trial to a maximum broadcast duration of 30 seconds per session.

#### Scenario: Return user starts broadcast
- **WHEN** an unsubscribed user whose `free_trial_used` flag is already `true` starts a new broadcast
- **THEN** the system SHALL start a 30-second countdown timer

#### Scenario: Subsequent trial expiration
- **WHEN** the 30-second countdown reaches zero during an active broadcast
- **THEN** the system SHALL immediately display a paywall dialog and SHALL terminate the broadcast within 5 seconds if the user does not subscribe

### Requirement: Trial state persistence
The system SHALL persist trial usage state as a boolean flag `free_trial_used`. The flag MUST be set to `true` the first time a user completes a broadcast (regardless of whether it was terminated by timer or manually stopped). The flag MUST NOT be cleared on app uninstall/reinstall (it is per-device, best-effort).

#### Scenario: Flag set after first broadcast
- **WHEN** an unsubscribed user stops or is timed out from their first broadcast session
- **THEN** the system SHALL set `free_trial_used` to `true` in persistent storage

#### Scenario: Flag persists across app restarts
- **WHEN** a user who has previously completed a broadcast re-opens the app
- **THEN** the `free_trial_used` flag SHALL still be `true`, and subsequent broadcasts SHALL use the 30-second limit

### Requirement: Subscribed users bypass trial limits
The system SHALL NOT apply any trial time limits to users with an active Pro subscription.

#### Scenario: Pro user starts broadcast
- **WHEN** a subscribed user starts a broadcast
- **THEN** the system SHALL NOT display any countdown timer or time-limit warnings
