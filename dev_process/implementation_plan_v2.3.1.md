# 实施方案 - iOS App 源选择界面 UI 优化 (v2.3.1)

针对用户反馈的“选择源界面太简陋”问题，本方案将对 `BroadcastScreen` 的预播阶段 UI 进行重新设计，旨在打造“Pro 版”的高级感与品质感。

## 视觉目标

- **去清单化**：废弃传统的 `CheckboxListTile` 清单模式。
- **高级卡片化**：引入带有大图标、副标题和渐变动效的**交互式源选择卡片 (Source Selection Cards)**。
- **动态交互**：选中卡片时增加高亮边框、阴影以及背景渐变。

## 拟议变更

### [mobile_pro] [main.dart](file:///Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_pro/lib/main.dart)

#### 1. 定义 `_buildSourceCard` 自定义组件
- **布局**：使用 `Container` 构建圆角卡片，内部采用 `Row` 或 `Column`。
- **图标**：使用 `kPrimaryColor` 或 `Colors.cyanAccent` 作为品牌色，图标尺寸放大。
- **文字**：增加标题 (Title) 和解释性副标题 (Subtitle)，例如：
    - `Screen Desktop` -> `共享屏幕 (iOS 全局采集)`
    - `Camera View` -> `高清摄像头 (前置/后置自适应)`
    - `Microphone` -> `双向麦克风 (高清音频)`
- **状态反馈**：
    - 选中状态：卡片具有 `kPrimaryColor` 渐变背景、发光边框 (`BoxShadow`)。
    - 未选中状态：半透明深色背景、深灰色文字。

#### 2. 界面布局重组
- **背景优化**：增加细微的放射性渐变或网格背景装饰。
- **START 按钮升级**：将“START BROADCAST”按钮改为全宽且带有更强的发光效果 (`Glow`).
- **间距调整**：优化纵向间距，使其在不同尺寸的 iPhone (从 Mini 到 Max) 上都有良好的视觉平衡。

## 验证计划

### 视觉验证
1. **对比检查**：对比旧版截图与新版 UI，确保新版更具“Pro”品质感（渐变、阴影、层级感）。
2. **交互检查**：点击卡片时，确保过渡动画流畅，状态切换清晰。
3. **响应式验证**：在模拟器中切换不同设备型号，确认布局不溢出。

---
**iOS 版本确认**：
当前 `pubspec.yaml` 中定义的版本号确实是 **2.0.0**。本次优化后，建议增加小版本号。
