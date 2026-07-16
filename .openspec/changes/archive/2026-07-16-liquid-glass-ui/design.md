## 背景

CastNow 目前在 Flutter 移动端和 Vue Web 端均使用深色主题加扁平半透明表面。视觉风格缺乏深度和质感。目标是在不改动功能的前提下，应用 Glassmorphism（液态玻璃 / 磨砂玻璃）——一种由 visionOS 和 Windows Fluent Design 推广的设计趋势——以提升应用的高端感。

当前强调色不统一：移动端使用靛蓝（#6366F1），Web 端使用琥珀色（#f59b0b）。两个平台将统一收敛为青色（#06B6D4）。

## 目标 / 非目标

**目标：**
- 对所有 Flutter 卡片、对话框和控制表面应用基于 BackdropFilter 的磨砂玻璃效果
- 对所有 Vue 面板、模态框和栏位应用 `backdrop-blur` Tailwind 工具类
- 将跨平台强调色统一为青色
- 定义三级模糊层级（轻微/中等/重度）
- 零功能回归 —— 所有现有流程不变

**非目标：**
- 修改任何业务逻辑（订阅、试用计时器、WebRTC 信令）
- 新增依赖或包
- 浅色模式支持
- 超出已有 AnimatedContainer 过渡范围的动画改动
- 重构组件树（仅装饰/样式层面的改动）

## 决策

### 决策 1：Flutter 玻璃效果通过 BackdropFilter + DecoratedBox 实现
**选择：** 用 `ClipRRect` > `BackdropFilter(filter: ImageFilter.blur(sigmaX: N, sigmaY: N))` > `DecoratedBox(decoration: BoxDecoration(...))` 包裹现有容器。

**理由：** `BackdropFilter` 是 Flutter 实现磨砂玻璃的标准 API，位于 `dart:ui` 中（无需额外依赖）。`ClipRRect` 确保模糊效果遵循圆角边界。

**备选方案：**
- `ShaderMask` —— 过于底层，无法产生真正的背景模糊
- 第三方包（`glassmorphism`、`frosted_glass`）—— 内置 API 已足够，无需额外依赖

### 决策 2：Web 端玻璃效果通过 Tailwind backdrop-blur 实现
**选择：** 将面板上的 `bg-slate-900` / `bg-slate-800` 替换为 `bg-white/5 backdrop-blur-xl`，遮罩层使用 `bg-black/40 backdrop-blur-2xl`。

**理由：** `backdrop-filter: blur()` 所有现代浏览器均支持（Safari 9+、Chrome 76+、Firefox 103+）。Tailwind 直接提供了相应的工具类。

**备选方案：**
- 自定义 CSS `backdrop-filter` —— 等效但不如 Tailwind 工具类可维护
- SVG 滤镜 —— 对基本模糊效果来说过度工程化

### 决策 3：统一青色强调色
**选择：** 在 `constants.dart` 中将 `kPrimaryColor` 从 `Color(0xFF6366F1)` 改为 `Color(0xFF06B6D4)`。Web 端将所有 `amber-*` 类替换为对应的 `cyan-*` 类。

**理由：** 投屏界面已大量使用 `Colors.cyanAccent`。统一为青色既保持一致性，又比靛蓝或琥珀色更具"科技/高端"感。青色与深色石板灰背景天然搭配，营造未来主义美学。

**备选方案：**
- 移动端保留靛蓝、Web 端保留青色 —— 延续不一致
- 统一为靛蓝 —— 视觉冲击力较弱，与投屏界面已有的青色不匹配
- 统一为琥珀色 —— 对科技产品来说过于温暖，不够"高端"

### 决策 4：三级模糊层级
**选择：**

| 层级 | Flutter sigma | Web 类名 | 用途 |
|------|-------------|---------|------|
| 轻微 | 4 | `backdrop-blur-sm` | 卡片、投屏码数字、信源选择条目 |
| 中等 | 8 | `backdrop-blur-xl` | 对话框、模态框、控制栏 |
| 重度 | 16 | `backdrop-blur-2xl` | 全屏遮罩、加载画面 |

**理由：** 提供视觉深度层次。更突出的 UI 元素使用更强的模糊，以强调其 Z 轴顺序。

### 决策 5：渐变边框高光
**选择：** Flutter 端使用 `BoxDecoration` 配合 `gradient` + `border: Border.all(color: Colors.white.withOpacity(0.1))`，并叠加一个带 `LinearGradient` 边框描边的内部 `Container`。Web 端使用 `border-t-white/20 border-l-white/15 border-b-white/5 border-r-white/5`。

**理由：** 模拟光线从左上角照射玻璃表面的效果，营造逼真的材质感。

## 风险 / 权衡

- **[性能] BackdropFilter 消耗 GPU**：低端设备上多个并发的 BackdropFilter 可能导致掉帧。→ 缓解措施：每个屏幕限制一个 BackdropFilter，避免嵌套。
- **[浏览器兼容性] 旧版 Safari 不支持 backdrop-filter**：Safari < 9 不支持 backdrop-filter。→ 缓解措施：可接受 —— CastNow 目标用户使用现代浏览器，Safari 9 发布于 2015 年。
- **[视觉一致性] Flutter 和 Web 的模糊效果可能略有差异**：CSS `blur()` 和 Flutter `ImageFilter.blur()` 渲染方式略有不同。→ 缓解措施：接受微小视觉差异，两者均能充分产生"磨砂"效果。
- **[强调色变更] 现有用户已习惯靛蓝色**：→ 缓解措施：青色在投屏界面中已存在，过渡会感觉自然。

## 迁移计划

1. 先部署 Web 端变更（风险更低，即时上线）
2. 通过 App Store 更新部署 Flutter 变更
3. 无需数据库迁移，无需 API 变更
4. 回滚方案：回退 git 提交并重新部署（Web）/ 重新提交构建（移动端）

## 待决问题

- 无。以上所有设计决策均已最终确定。
