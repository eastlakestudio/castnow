## 动机

代码评审暴露出多个关键问题：`App.vue` 高达 1552 行的巨石组件，以及 2 分钟免费试用对持续变现而言过于宽松。Android 平台支撑增加维护负担却没有对应收入。本次变更系统性地解决这些问题——在一个协调的版本中提升代码质量和订阅转化率。

## 变更内容

- **BREAKING**：从 `apps/mobile_pro/` 中移除 Android 平台支持，包括 Android 专属的 Platform Channel、构建配置和清单文件
- 将 `App.vue`（1552行）拆分为 composables（`useWebRTC`、`useLayout`、`useMediaStream`）和子组件（`SenderView`、`ReceiverView`）
- 将 Flutter `broadcast_screen.dart`（1465行）提取为领域服务类和独立 Widget
- **阶梯试用规则**：首次会话 2 分钟无中断；未订阅后的后续会话限制为 30 秒；试用状态持久化于 `localStorage`（Web）和 `SharedPreferences`（Flutter）
- 修复 `resetApp()` 中的重复关闭逻辑、触摸拖拽的 `passive` 警告、Flutter `MediaStreamTrackState` 枚举比较改用 `.live` 替代原始索引

## 能力定义

### 新增能力
- `tiered-free-trial`：基于使用历史的阶梯免费试用时长（首次2分钟，后续30秒），按设备持久化
- `codebase-modularization`：Web 和 Flutter 代码分解标准——Vue 单文件组件不超过 500 行，Flutter Screen 不超过 600 行

### 变更能力
<!-- 本次为首个正式规格周期，无需修改已有规格 -->

## 影响面

- **Web**：`App.vue` → 多个 composables + 组件；`sw.js` 缓存策略升级为 Stale-While-Revalidate
- **Flutter**：`broadcast_screen.dart` 拆分；`receive_screen.dart` Track 状态修复；`main.dart` 试用逻辑；Android 目录树删除
- **CI/CD**：移除 Android 构建流水线
- **依赖**：无需新增第三方包；`@fission-ai/openspec` 已安装用于规格管理
