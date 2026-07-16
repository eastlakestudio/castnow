## 1. Flutter 配色体系与玻璃基础

- [x] 1.1 更新 `constants.dart`：将 `kPrimaryColor` 从靛蓝（#6366F1）改为青色（#06B6D4），将 `kSurfaceColor` 从深靛蓝（#1E1B4B）改为深石板灰（#0F172A）
- [x] 1.2 在 `lib/widgets/glass_container.dart` 中创建可复用的 `GlassContainer` 组件，支持配置模糊 sigma、边框透明度和子组件
- [x] 1.3 验证：`flutter analyze` 零错误通过

## 2. Flutter 首页玻璃化

- [x] 2.1 将品牌区域容器背景替换为 `GlassContainer`（轻微模糊，sigma=4）
- [x] 2.2 将投屏/接收操作按钮替换为玻璃风格容器（BackdropFilter + 半透明填充）
- [x] 2.3 将 Pro 徽章渐变边框替换为青色玻璃风格
- [x] 2.4 将页脚链接容器添加轻微玻璃效果
- [x] 2.5 验证：运行应用，确认首页所有表面均显示磨砂玻璃效果，布局无回退

## 3. Flutter 投屏界面玻璃化

- [x] 3.1 对信源选择视图的背景卡片应用 `GlassContainer`（轻微模糊）
- [x] 3.2 将状态叠加层（`_buildStatusOverlay`）背景替换为 `backdrop-blur-md` 等效效果（sigma=8）
- [x] 3.3 将提示栏（`_buildTipBar`）替换为玻璃容器（sigma=8）
- [x] 3.4 将 START BROADCAST 按钮样式改为青色玻璃渐变
- [x] 3.5 对投屏中占位画面添加玻璃叠加效果
- [x] 3.6 验证：发起一次投屏，确认信源选择器、状态栏、提示栏和预览画面均显示玻璃效果。确认试用计时器和投屏码显示功能正常。

## 4. Flutter 投屏组件玻璃化

- [x] 4.1 更新 `CodeDisplay` 组件：每个数字框使用 `GlassContainer` 配合轻微模糊，连接成功后显示青色发光边框
- [x] 4.2 更新 `BroadcastControls` 组件：栏位背景使用重度玻璃（sigma=16），各控制按钮使用轻微玻璃
- [x] 4.3 更新 `SourceSelector` 组件：每张信源卡片获得玻璃背景，选中时显示渐变高光边框
- [x] 4.4 更新 `PaywallDialog`：对话框表面使用中等玻璃（sigma=8），功能行使用轻微玻璃
- [x] 4.5 验证：逐一打开各组件的对应界面，确认玻璃效果可见且风格一致

## 5. Flutter 接收界面玻璃化

- [x] 5.1 将投屏码输入数字框替换为 `GlassContainer`（轻微模糊，sigma=4）
- [x] 5.2 将 CONNECT 按钮替换为青色玻璃渐变样式
- [x] 5.3 将"向投屏者索取密钥"文字容器添加轻微玻璃效果
- [x] 5.4 将接收端活跃状态控制栏（关闭、麦克风、音量按钮）替换为玻璃背景
- [x] 5.5 将画中画容器边框替换为玻璃风格
- [x] 5.6 验证：加入一路画面，确认接收界面所有 UI 均显示玻璃效果，视频播放不受影响

## 6. Web 配色体系与玻璃基础

- [x] 6.1 更新 `tailwind.config.js`：将主题扩展中的琥珀色引用替换为青色
- [x] 6.2 验证：`npm run build` 构建成功

## 7. Web 首页与导航玻璃化

- [x] 7.1 更新 `LandingView.vue`：操作按钮使用 `backdrop-blur-xl bg-white/5 border-white/10`，强调文字使用 `text-cyan-400` 替换 `text-amber-500`
- [x] 7.2 更新 `App.vue` 中的 header：使用 `backdrop-blur-md` 替换当前样式，强调色切换为青色
- [x] 7.3 更新页脚链接悬停色为 `hover:text-cyan-400`
- [x] 7.4 验证：加载首页，确认按钮和头部显示玻璃效果

## 8. Web 投屏与信源视图玻璃化

- [x] 8.1 更新 `SourceSelectView.vue`：信源切换卡片使用 `backdrop-blur-sm bg-white/5`，选中时显示青色强调边框
- [x] 8.2 更新 `SenderView.vue`：连接状态栏、投屏码显示、控制面板均使用玻璃表面
- [x] 8.3 验证：在 Web 端走一遍投屏流程，确认所有视图显示玻璃效果

## 9. Web 接收端与模态框玻璃化

- [x] 9.1 更新 `ReceiverView.vue`：投屏码输入数字使用 `backdrop-blur-sm bg-white/5`，连接按钮使用青色渐变
- [x] 9.2 更新 `App.vue` 中接收端活跃控制栏：`backdrop-blur-2xl bg-black/40`，活跃麦克风使用青色强调
- [x] 9.3 更新 `InfoModal.vue`：模态框背景使用 `backdrop-blur-xl bg-slate-900/80`
- [x] 9.4 更新 `App.vue` 中 Toast 通知：`backdrop-blur-md`，成功/信息状态使用青色强调
- [x] 9.5 更新 Firefox 引导遮罩和投屏结束对话框为玻璃风格
- [x] 9.6 验证：完整的接收流程配合玻璃效果正常工作，画中画和并排布局不受影响

## 10. 最终验证

- [x] 10.1 运行 `flutter analyze` —— 零错误
- [x] 10.2 运行 `flutter test` —— 所有已有测试通过
- [x] 10.3 运行 `cd apps/web && npm run build` —— 零错误
- [x] 10.4 手动冒烟测试：在移动端和 Web 端各完成一次投屏→接收完整流程，确认玻璃效果随处可见，无功能回退
