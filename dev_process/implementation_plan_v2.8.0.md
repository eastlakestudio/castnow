# Implementation Plan - 手机端本地 PIP 预览 (v2.8.0)

本方案旨在为 `CastNow Pro` 移动端提供本地预览的“画中画”体验。当用户同时开启“屏幕镜像”和“摄像头”时，预览区域将大窗显示屏幕内容，右下角小窗叠加显示摄像头画面。

## 用户审核项
> [!IMPORTANT]
> **资源消耗**：开启双路渲染器会略微增加手机的 CPU/GPU 负担和发热，但在现代 iOS 设备上应属于正常范围。

## 拟议变更

### 1. 状态管理与初始化
- 在 `_BroadcastScreenState` 中新增 `_cameraRenderer` 用于独立渲染摄像头画面。
- 在 `initState` 中初始化，并在 `dispose` 中释放。

### 2. 媒体流分配逻辑
- 修改 `_startBroadcast`：
    - **屏幕流**：关联至 `_localRenderer`。
    - **摄像头流**：单独创建一个预览用的 `MediaStream` 关联至 `_cameraRenderer`。
    - **合并流**：继续保持 `_localStream` 作为包含所有 Track 的全量流，用于 PeerJS 发送。

### 3. UI 布局重构
- 将原有的单路 `RTCVideoView` 修改为 `Stack` 组合布局。
- **背景层**：主显示区（通常是屏幕内容）。
- **浮动层**：小窗显示区（通常是摄像头内容），采用圆角、边框和阴影进行美化。

---

## 涉及文件

#### [MODIFY] [broadcast_screen.dart](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_pro/lib/screens/broadcast_screen.dart)
- 添加 `_cameraRenderer` 变量。
- 更新生命周期管理代码。
- 更新 `_startBroadcast` 中的渲染器赋值逻辑。
- 重构 `build` 方法中的预览区域 UI。

---

## 验证计划

### 自动化检查
- 运行 `dart analyze` 确保无语法错误。

### 手动验证
- 在模拟器/真机开启“屏幕+摄像头”模式，观察是否出现画中画。
- 切换前后摄像头，确认小窗画面同步更新。
- 关闭其中一个源，确认 UI 自动切换回单路全屏。
