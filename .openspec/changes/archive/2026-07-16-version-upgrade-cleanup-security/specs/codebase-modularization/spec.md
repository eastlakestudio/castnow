## 新增需求

### 需求：Vue 组件文件大小限制
Web 应用中所有 Vue 单文件组件（`.vue` 文件）SHALL NOT 超过 500 行代码（不含空行和纯注释行）。超限组件 MUST 分解为 composables（`composables/`）和子组件（`components/`）。

#### 场景：新组件超限
- **WHEN** 开发者创建或修改一个超过 500 行的 `.vue` 组件
- **THEN** 代码审查 MUST 拒绝该变更，要求拆分为更小的文件

#### 场景：现有 App.vue 拆分
- **WHEN** `App.vue`（当前 1552 行）拆分完成
- **THEN** `apps/web/` 下的单个 `.vue` 文件 SHALL NOT 超过 500 行

### 需求：Flutter 界面文件大小限制
`lib/screens/` 目录下所有 Flutter Screen/Widget 文件（`.dart` 文件）SHALL NOT 超过 600 行代码。超限逻辑 MUST 提取到 `lib/services/` 中的服务类或 `lib/widgets/` 中的 Widget 文件。

#### 场景：Screen 超限
- **WHEN** Flutter Screen 文件超过 600 行
- **THEN** 业务逻辑 SHALL 提取至服务类，UI 子组件 SHALL 提取至独立 Widget 文件

### 需求：App.vue Composable 提取
Web 端 `App.vue` SHALL 分解为以下结构：
- `composables/useWebRTC.js`——PeerJS 连接、呼叫处理、ICE 监控
- `composables/useLayout.js`——PiP 位置、拖拽/缩放、分割比例、交换逻辑
- `composables/useMediaStream.js`——getDisplayMedia、getUserMedia、Track 管理
- `components/SenderView.vue`——发送端 UI：预览、代码显示、控制栏
- `components/ReceiverView.vue`——接收端 UI：流显示、PiP/并列布局、控制栏

#### 场景：拆分后的 App.vue
- **WHEN** 拆分完成
- **THEN** `App.vue` SHALL 仅包含应用级状态编排，SHALL NOT 超过 200 行

### 需求：Flutter broadcast_screen 分解
Flutter `broadcast_screen.dart`（当前 1465 行）SHALL 分解为：
- `lib/services/webrtc_broadcast_service.dart`——PeerJS 连接、重试逻辑、呼叫处理
- `lib/services/media_capture_service.dart`——屏幕/摄像头/麦克风采集与权限
- `lib/widgets/source_selector.dart`——源选择 UI 卡片
- `lib/widgets/broadcast_controls.dart`——控制栏（静音、翻转、停止）
- `lib/widgets/code_display.dart`——6 位分享码展示

#### 场景：拆分后的 broadcast_screen.dart
- **WHEN** 拆分完成
- **THEN** `broadcast_screen.dart` SHALL NOT 超过 400 行
## ADDED Requirements

### Requirement: Vue component file size limit
All Vue single-file components (`.vue` files) in the Web application SHALL NOT exceed 500 lines of code (excluding blank lines and comment-only lines). Components exceeding this limit MUST be decomposed into composables (`composables/`) and sub-components (`components/`).

#### Scenario: New component exceeds limit
- **WHEN** a developer creates or modifies a `.vue` component that exceeds 500 lines
- **THEN** code review MUST reject the change and request decomposition into smaller files

#### Scenario: Existing `App.vue` decomposition
- **WHEN** the decomposition of `App.vue` (currently 1552 lines) is complete
- **THEN** no single `.vue` file in `apps/web/` SHALL exceed 500 lines

### Requirement: Flutter screen file size limit
All Flutter screen/widget files (`.dart` files in `lib/screens/`) SHALL NOT exceed 600 lines of code. Logic exceeding this limit MUST be extracted into dedicated service classes in `lib/services/` or widget files in `lib/widgets/`.

#### Scenario: Screen exceeds limit
- **WHEN** a Flutter screen file exceeds 600 lines
- **THEN** business logic SHALL be extracted to a service class and UI sub-components SHALL be extracted to separate widget files

### Requirement: Composable extraction from App.vue
The Web `App.vue` SHALL be decomposed into the following structure:
- `composables/useWebRTC.js` — PeerJS connection, call handling, ICE monitoring
- `composables/useLayout.js` — PiP position, drag/resize, split ratio, swap logic
- `composables/useMediaStream.js` — getDisplayMedia, getUserMedia, track management
- `components/SenderView.vue` — sender UI including preview, code display, controls
- `components/ReceiverView.vue` — receiver UI including stream display, PiP/Side-by-Side, controls

#### Scenario: App.vue after decomposition
- **WHEN** decomposition is complete
- **THEN** `App.vue` SHALL contain only app-level state orchestration and SHALL NOT exceed 200 lines

### Requirement: Flutter broadcast screen decomposition
The Flutter `broadcast_screen.dart` (currently 1465 lines) SHALL be decomposed into:
- `lib/services/webrtc_broadcast_service.dart` — PeerJS connection, retry logic, call handling
- `lib/services/media_capture_service.dart` — screen/camera/mic capture with permissions
- `lib/widgets/source_selector.dart` — source selection UI cards
- `lib/widgets/broadcast_controls.dart` — control bar (mute, flip, stop)
- `lib/widgets/code_display.dart` — 6-digit sharing code display

#### Scenario: broadcast_screen.dart after decomposition
- **WHEN** decomposition is complete
- **THEN** `broadcast_screen.dart` SHALL NOT exceed 400 lines
