## 为什么

CastNow 当前 UI 使用扁平的半透明叠加和简单阴影，缺乏现代高端应用应有的深度感和质感。实施液态玻璃（Glassmorphism）——一种由 visionOS 和 Fluent Design 推广的磨砂玻璃视觉风格——将提升产品感知品质、强化 Pro 订阅价值主张，并在移动端和 Web 端建立统一的视觉识别。

## 变更内容

- **Flutter（移动端）**：所有卡片表面、对话框、底部栏和投屏码显示容器替换为 `BackdropFilter` + 半透明渐变层。信源选择卡片、付费墙对话框、投屏控制栏和首页操作按钮升级为玻璃材质。
- **Web 端（Vue/Tailwind）**：所有面板、模态框、控制栏和首页卡片从实色 `bg-slate-900` 升级为 `backdrop-blur-xl` + `bg-white/5` 玻璃表面。Web 与移动端统一使用青色（Cyan）强调色。
- **配色体系**：移动端主色从靛蓝（#6366F1）改为青色/蓝绿色，与投屏界面已有的青色强调色一致。Web 端强调色从琥珀色（#f59b0b）改为青色/蓝绿色，实现跨平台一致性。
- **无功能变更**：P2P 信令、媒体采集、订阅逻辑和试用计时器保持不变。

## 能力划分

### 新增能力

- `liquid-glass-design-system`：应用于 Flutter 移动端和 Vue Web 端所有 UI 表面的统一磨砂玻璃视觉设计体系。包含基于 BackdropFilter 的玻璃容器、渐变边框、分层模糊深度和青色主色调。

### 修改的能力

<!-- 无 —— 现有规格级行为不变 -->

## 影响范围

- **受影响代码**：8 个 Flutter 文件（`home_screen.dart`、`broadcast_screen.dart`、`receive_screen.dart`、`code_display.dart`、`source_selector.dart`、`broadcast_controls.dart`、`paywall_dialog.dart`、`constants.dart`）和 6+ 个 Vue 组件（`LandingView.vue`、`SenderView.vue`、`ReceiverView.vue`、`SourceSelectView.vue`、`InfoModal.vue`、`App.vue`、`tailwind.config.js`）
- **依赖**：无需新增包。Flutter `BackdropFilter` 为内置 API。Web `backdrop-filter` 为标准 CSS。
- **平台**：iOS、Web（macOS/Windows/Linux 浏览器）
- **破坏性变更**：无。所有变更仅涉及视觉层面，组件 API 保持兼容。
