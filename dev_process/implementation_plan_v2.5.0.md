# 实施方案 - iOS App 增加摄像头翻转功能 (v2.5.0)

本方案旨在为 `mobile_pro` 增加“切换摄像头”功能，允许用户在预览或直播过程中无缝切换前后摄像头。

## 用户审核事项

> [!IMPORTANT]
> **多轨道处理**：由于应用支持同时发送“屏幕”和“摄像头”，切换逻辑必须精准作用于摄像头轨道，而不影响屏幕共享轨道。我将引一个专用的 `_cameraTrack` 变量来管理此状态。

## 拟议变更

### [mobile_pro] [main.dart](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_pro/lib/main.dart)

#### 1. 状态管理
- **[NEW]** `MediaStreamTrack? _cameraTrack`: 用于缓存当前活动的摄像头视频轨道。
- **[MODIFY]** `_startBroadcast`: 在成功获取 `camStream` 后，将其视频轨道赋值给 `_cameraTrack`。

#### 2. 切换逻辑
- **[NEW]** `Future<void> _switchCamera()`:
    - 检查 `_cameraTrack` 是否为空且类型为视频。
    - 调用 `Helper.switchCamera(_cameraTrack!)` 进行硬件级翻转。
    - 该方法由 `flutter_webrtc` 提供，支持在通话中动态切换。

#### 3. UI 增强
- **[MODIFY]** 在广播控制面板（底部的操作行）中增加一个“翻转”图标按钮 (`Icons.flip_camera_ios_rounded`)。
- **条件显示**：该按钮仅在 `_shareCamera` 为 `true` 且广播已启动时显示。
- **视觉风格**：保持 Premium 风格，使用半透明圆形背景。

## 验证计划

### 手动验证
1. **多流切换测试**：启动“屏幕+摄像头”广播，点击翻转按钮，确认摄像头画面从前置变为后置，而屏幕共享画面保持不变。
2. **预览切换测试**：在未连接 Peer 仅预览时确认翻转是否生效。
3. **性能测试**：确认频繁点击翻转按钮不会导致流中断或 App 崩溃。
