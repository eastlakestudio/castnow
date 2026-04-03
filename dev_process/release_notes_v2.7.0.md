# CastNow Pro v2.8.0 迭代升级说明书 (Release Notes)

本次迭代完成了 CastNow Pro 的核心媒体引擎升级与生产环境打包准备，实现了多流并发同步与完全的模块化架构。

## 1. 核心功能突破 (Core Features)

### 🚀 多流并发与实时控制
- **同步采集**：支持同时开启 **屏幕镜像**、**实时摄像头** 与 **高清麦克风**。三路轨道实现单通道无缝并发传输。
- **动态镜头翻转 (Flip Camera)**：支持在广播/直播过程中一键切换前后摄像头，不干扰屏幕共享流。
- **隐私保护策略**：默认开启麦克风静音 (`Mute`) 模式，确保启动时的音频安全性。
- **本地画中画预览 (Local PIP Preview)**：【新增】在手机推流界面同步显示屏幕镜像与摄像头小窗，实现“发端即看”的完整推流视野。

## 2. 架构优化与品牌分发

### 🏗️ 模块化解耦 (Architectural Refactoring)
- **工程化重构**：将全量代码拆分为 `core/` (常量)、`screens/` (页面) 和 `widgets/` (组件)，从单文件 1100 行精简至标准模块化结构，提升可维护性。

### 📦 品牌与打包
- **正式更名**：Apple Store 显示名称更新为 **“CastNow - Screen Cast”**。
- **IPA 预编译**：生成符合 App Store 配置要求的 IPA 安装包（v2.0.0 编译版），支持 TestFlight 快速分发。

## 3. 版本文件清单

| 文件类型 | 存放路径 | 说明 |
| :--- | :--- | :--- |
| **IPA 安装包** | `build/ios/ipa/castnow_pro_mobile.ipa` | 可直接用于 TestFlight 测试 |
| **设计方案** | `dev_process/implementation_plan_v2.7.0.md` | 技术路线与决策记录 |
| **变更日志** | `dev_process/walkthrough_v2.7.0.md` | 代码变更详细记录 |

---
**CastNow 研发团队**
*2026-04-03*
