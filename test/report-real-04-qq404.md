# winget 诊断报告

- 时间：2026-10-20 13:34:17
- 工具版本：winget-diagnose v0.2（诊断工具本身由 AI 起草，知识库证据分级见 kb/errors.json _meta）

## 错误指纹

- `0x80190194`

## 知识库匹配（按证据等级）

### `0x80190194` HTTP 404 (WinHTTP 映射)  **[证据等级 A]**

- 官方描述：winget download 命令会直接显示此码；install 路径可能包一层 0x8A150008 不露原码
- 症状：下载 URL 已失效。
- 可能原因：
  - 上游发布新版本后删除/移动了旧安装包，manifest 未同步
  - manifest 中的 InstallerUrl 手写错误
  - 上游 CDN 策略变更导致旧路径下线
- 建议动作（工具不会替你执行）：
  - 到 winget-pkgs 仓库搜该包名的 issue，多半已有人报『InstallerUrl is 404』；没有就发一个（附 winget --info 版本与完整 URL）
  - 等待社区更新 manifest，或本地 manifest 指向新版本 URL 自装
  - 重试意义不大：404 是确定态，不像 502/503 会自己好
- 依据：一手实测 2026-10-20：winget download Tencent.QQ 9.7.23.29392 → 0x80190194，URL https://dldir1v6.qq.com/.../QQ9.7.23.29392.exe 实测 404，对应 winget-pkgs issue #379191（仍 open）；HTTP 映射为官方通用知识

## 环境体检

| 项目 | 值 |
|------|-----|
| winget 版本 | v1.29.380 |
| 日志路径 | 日志 %LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir |
| 当前是否管理员 | 否 |
| C 盘剩余 | 29.7 GB |
| winhttp 代理 | \| Direct access (no proxy server). |
| 环境变量代理 | （未设置） |
| 已配置源 | --------------------------------------------------------------- \| msstore https://storeedgefd.dsx.mp.microsoft.com/v9.0 false \| winget https://cdn.winget.microsoft.com/cache false \| winget-font https://cdn.winget.microsoft.com/fonts true |
| LocalManifestFiles | 未设置（settings.json 不存在，默认关闭） |
| 报错中 URL 探测 | https://dldir1v6.qq.com/qqfile/qq/PCQQ9.7.23/QQ9.7.23.29392.exe → HTTP 404 |

## 边界声明

- 本工具**只诊断、只建议**，上面所有修改类命令由你决定是否执行；
- 证据等级含义：**A**=作者一手实测；**B**=官方文档或多个独立来源一致；**C**=单一来源/推断，当线索别当结论；
- 知识库欢迎带证据的补充（C→B→A 的升级通道见仓库 README）。

