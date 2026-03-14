<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/drive/1BL206G8s_2m2bExdw__0xZaVqXwlxX6V

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Set the `GEMINI_API_KEY` in [.env.local](.env.local) to your Gemini API key
- [x] **Git 上传**: 已通过 `git push` 将 APK 文件提交到远程仓库 `main` 分支。
- [x] **大小写修复**: 发现 Git 之前记录的文件名为 `CastNow.apk`，现已纠正为小写的 `castnow.apk`。Vercel 是区分大小写的，这将彻底解决 404 问题。

> [!IMPORTANT]
> Vercel 正在基于最新提交进行自动构建。请等待 1-2 分钟让部署完成，然后访问 [https://castnow.vercel.app/castnow.apk](https://castnow.vercel.app/castnow.apk) 确认下载。
3. Run the app:
   `npm run dev`
