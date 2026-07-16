## 背景

CastNow 当前运行着巨石 `App.vue`（1552行）和 `broadcast_screen.dart`（1465行）。免费版无条件提供每次 2 分钟试用。Android 支撑存在但不产生收入。Service Worker 使用简单的 Cache-First 策略。存在若干 Bug（重复关闭逻辑、触摸处理器警告、不安全的枚举比较）。

本文档涵盖同时解决上述所有问题的技术方案。

## 目标 / 非目标

**目标：**
- 将巨石 Web 和 Flutter 文件分解为严格行数限制内的可维护模块
- 从 `apps/mobile_pro/` 中移除所有 Android 专属代码、构建配置和 Platform Channel
- 实现阶梯免费试用：首次 120 秒，后续 30 秒，按设备持久化
- 修复代码评审中发现的所有 Bug


**非目标：**
- 部署自托管 PeerJS 服务器（仅提供指南）
- 添加 TURN 服务器支持（后续规划）
- 修改 WebRTC v9.1 握手协议
- 修改 PiP 拖拽/缩放交互模型（仅修复触摸处理器属性）

## 技术决策

### D1：Web Composable 提取策略
**选择**：提取至 `composables/useWebRTC.js`、`composables/useLayout.js`、`composables/useMediaStream.js`，以及 `components/SenderView.vue`、`components/ReceiverView.vue`。

**理由**：Vue 3 Composition API 的 composable 是提取响应式逻辑的惯用方式。每个 composable 对应一个内聚的领域（WebRTC 生命周期、布局操作、媒体采集）。子组件处理纯渲染。`App.vue` 作为薄编排层保留（~150行）。

**备选方案**：Pinia store——被拒绝，因为这是组件局部响应式状态而非全局应用状态。Mixins——被拒绝，Vue 3 中已弃用。

### D2：Flutter Service 提取
**选择**：将 `webrtc_broadcast_service.dart` 和 `media_capture_service.dart` 作为纯 Dart 类提取（非 `ChangeNotifier`），UI 状态保留在 Screen 的 `setState` 中。Widget 提取为 `source_selector`、`broadcast_controls`、`code_display`。

**理由**：Flutter 惯例将业务逻辑分离到 service 类中。广播状态是 Screen 局部的，纯类足以胜任。Provider 仅保留给订阅状态。Widget 提取遵循 Flutter 组合式 Widget 树模式。

### D3：阶梯试用状态存储
**选择**：`localStorage` 键 `free_trial_used`（Web）和 `SharedPreferences` 键 `free_trial_used`（Flutter），均为布尔类型。首次广播会话结束后（任意终止路径）置为 `true`。

**理由**：两者均为同步操作，广泛支持，按设备存储。无需后端。标记在会话结束时（而非开始时）设置，防止用户在首次会话中重启应用绕过限制。

**备选方案**：`IndexedDB`——对单个布尔值过度设计。服务端账户——增加认证摩擦，违背 CastNow 零注册理念。

### D4：Android 移除范围
**选择**：删除 `apps/mobile_pro/android/` 目录，移除 `Platform.isAndroid` 守卫的 `castnow_picker` MethodChannel 调用，剥离 Android 专属权限检查，移除 `wakelock_plus` Android 配置。

**理由**：完全移除减少维护成本和构建时间。iOS-only 简化 Flutter 项目。

### D5：Service Worker 缓存策略
**选择**：Stale-While-Revalidate——立即提供缓存内容，后台拉取新版本，更新缓存。

**理由**：兼顾即时加载（缓存）与内容新鲜度（后台更新）。比无限提供过期内容的 Cache-First 更好的用户体验。

## 风险 / 权衡

| 风险 | 缓解措施 |
|------|----------|
| 分解可能引入 WebRTC 呼叫生命周期回归 | 每个 composable 独立提取并测试；保留完整发送→接收集成测试 |
| `free_trial_used` 可被用户清除（浏览器 devtools / 清除应用数据） | 可接受——尽力而为，标记按设备存储。清除数据的高级用户是可忽略的收入损失 |
| Android 移除可能影响现有 Android 用户 | 在发布说明中公告弃用；应用商店列表更新为「不再支持」 |

## 迁移计划

1. **预发布**：为当前状态打标签 `v3.1.2`（最后一个支持 Android 的版本）
2. **部署**：Web 变更通过 `castnow-v2` SW 缓存键部署到 Vercel，实现干净切换
3. **iOS**：App Store 提交，发布说明注明 Android 弃用
4. **回滚**：Web——回退 Vercel 部署；iOS——App Store Connect 中保留上一个构建版本
5. **服务端**：无需变更（Web 服务无 RTMP 推流依赖）

## 待决问题

- 是否应在特定情况下重置试用（如大版本升级后）？→ 推迟至上线后数据分析
- 是否需要服务端试用计数器防止多设备滥用？→ 不，遵循零注册理念
