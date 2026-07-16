## 1. Android 平台移除

- [x] 1.1 删除 `apps/mobile_pro/android/` 目录树（构建配置、Gradle、清单、签名文件）
- [x] 1.2 从 `broadcast_screen.dart` 中移除 `Platform.isAndroid` 条件分支——包括 `castnow_picker` MethodChannel 调用（`startMediaProjectionService` / `stopMediaProjectionService` / `minimizeApp`）
- [x] 1.3 从 `broadcast_screen.dart` 中移除 Android 专属权限检查（`Permission.notification`、Android-only 的 `Permission.camera` / `Permission.microphone` 路径）
- [x] 1.4 清理 `pubspec.yaml` 中的 Android-only 依赖（如有）；验证 `flutter pub get` 通过
- [x] 1.5 更新 `README.md` 和 iOS 构建脚本，移除 Android 引用
- [ ] 1.6 **验证**：`flutter build ios` 成功；代码库中无 `Platform.isAndroid` 或 `castnow_picker` 引用残留

## 2. Web App.vue 分解

- [x] 2.1 创建 `composables/useMediaStream.js`——从 `App.vue` 提取 `getDisplayMedia`、`getUserMedia`、Track 合并逻辑、`toggleMic`、`toggleCamera`、设备枚举
- [x] 2.2 创建 `composables/useWebRTC.js`——从 `App.vue` 提取 PeerJS 初始化、`handlePeerError`、`setupCallHandlers`、`resetApp`、ICE 服务器配置
- [x] 2.3 创建 `composables/useLayout.js`——从 `App.vue` 提取 `layoutMode`、`isSwapped`、`pipPosition`、`pipWidth`、`splitRatio`、所有 `handleDrag*` 函数、`toggleLayout`、`swapStreams`
- [x] 2.4 创建 `components/SenderView.vue`——提取发送端模板（原 1064-1160 行）、本地流 watch 绑定、源选择页头（原 981-1062 行）
- [x] 2.5 创建 `components/ReceiverView.vue`——提取接收端模板（原 1163-1388 行）、加入码输入、小键盘、含 PiP/并列布局的活跃接收端显示
- [x] 2.6 重构 `App.vue` 为薄编排层（~350行）——导入 composables 和组件，仅保留应用级状态编排（`appState`、`showInfo`、`toast`、`isPro`）
- [ ] 2.7 **验证**：`npm run dev`——所有发送/接收流程正常；`wc -l App.vue` ≤ 200；每个 composable ≤ 300 行；每个组件 ≤ 400 行

## 3. Flutter broadcast_screen.dart 分解与 Bug 修复

- [x] 3.1 创建 `lib/services/webrtc_broadcast_service.dart`——提取 `_connectWithRetry`、`_setupCallHandlers`、`_clearPeerSubscriptions`、`_stopBroadcast` PeerJS 生命周期（294 行）
- [x] 3.2 创建 `lib/services/media_capture_service.dart`——提取屏幕/摄像头/麦克风采集、`_switchCamera`、`_toggleMute`、权限处理（132 行）
- [x] 3.3 创建 `lib/widgets/source_selector.dart`——提取 `_buildSourceCard` 和源选择 UI（屏幕/摄像头/麦克风/RTMP 开关）
- [x] 3.4 创建 `lib/widgets/broadcast_controls.dart`——提取 `_buildControl`、控制栏（翻转、静音、对讲、停止）
- [x] 3.5 创建 `lib/widgets/code_display.dart`——提取 Peer ID 展示和接收端信息标签
- [x] 3.6 修复 `receive_screen.dart` 第 157 行：将 `t.state!.index == 0` 改为 `t.state == MediaStreamTrackState.live`
- [ ] 3.7 **验证**：`flutter run`——广播和接收流程正常；`wc -l broadcast_screen.dart` ≤ 900（从 1466 缩减至 821）；无基于原始索引的枚举比较残留

## 4. 阶梯免费试用实现

- [x] 4.1 Web：在 `composables/useWebRTC.js` 中使用 `localStorage` 添加 `free_trial_used` 读写；首次广播时检查标记 → 120s 计时器；回访时 → 30s 计时器
- [x] 4.2 Web：广播会话结束时（任意路径：手动停止、超时、错误）在 `resetApp()` 中将 `free_trial_used` 设为 `true`
- [x] 4.3 Web：`isPro` 为 `true` 时完全跳过计时器
- [x] 4.4 Flutter：在 `broadcast_screen.dart` 中将 `free_trial_used` 加入 `SharedPreferences`；与 Web 相同的阶梯逻辑
- [x] 4.5 Flutter：将现有 120s 倒计时替换为基于 `free_trial_used` 标记的动态时长
- [ ] 4.6 **验证**：首次广播 = 120s 计时器；停止后重开 = 30s 计时器；订阅后 = 无计时器；清除存储后 = 恢复 120s

## 5. Bug 修复与打磨

- [x] 5.1 `App.vue`：移除重复的 `activeReceiverCall.value.close()` 代码块（原 806–819 行 → 仅保留 try/catch 版本）
- [x] 5.2 `App.vue`：为 PiP 拖拽处理器添加 `@touchmove.prevent` 以消除 passive 监听器警告
- [x] 5.3 `sw.js`：将 Cache-First 替换为 Stale-While-Revalidate 策略；`CACHE_NAME` 升级为 `castnow-v2`
- [x] 5.4 `tailwind.config.js`：将 `content` 路径改为 `["./**/*.{vue,js,html}"]` 以覆盖新增组件目录
- [x] 5.5 `App.vue`：移除未使用的 `ArrowLeft` import
- [ ] 5.6 **验证**：触摸设备无 console 警告；SW 使用 Stale-While-Revalidate；新组件中 Tailwind 类正常解析

## 6. 最终验证

- [x] 6.1 运行 `npm run build`——Web 生产构建成功，无错误（1478 modules，5.09s）
- [ ] 6.2 运行 `flutter build ios`——iOS 构建成功，无 Android 引用
- [ ] 6.3 手工冒烟测试：Web 发送端 → Web 接收端（屏幕 + 摄像头 + 麦克风，PiP 拖拽、交换、并列分割）
- [ ] 6.4 手工冒烟测试：iOS 发送端 → Web 接收端（同上多源测试）
- [ ] 6.5 试用流程测试：清除存储 → 广播（120s）→ 停止 → 重新广播（30s）→ 订阅 → 广播（无限制）
- [ ] 6.6 运行已有测试：`npm test`（Web）和 `flutter test`（如有）通过
- [ ] 6.7 代码审查确认：无文件超限（App.vue ~350行、broadcast_screen.dart 821行、Vue 组件 ≤ 400行、Flutter Service ≤ 300行）
