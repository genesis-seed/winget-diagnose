# winget 诊断报告

- 时间：2026-10-20 13:33:59
- 工具版本：winget-diagnose v0.2（诊断工具本身由 AI 起草，知识库证据分级见 kb/errors.json _meta）

## 错误指纹

- `0x8A150014`

## 知识库匹配（按证据等级）

### `0x8A150014` APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND  **[证据等级 B]**

- 官方描述：No packages found
- 症状：搜不到包。
- 可能原因：
  - 包名拼写/别名不对
  - 源索引过期
  - 该包在你所用源中不存在（msstore 与 winget 源覆盖不同）
- 建议动作（工具不会替你执行）：
  - winget source update 刷新索引后重搜
  - winget search 用关键词模糊搜，确认正确 ID
  - 指定 --source winget 或 --source msstore 分别试
- 依据：官方 returnCodes 定义 + 源机制文档

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

## 边界声明

- 本工具**只诊断、只建议**，上面所有修改类命令由你决定是否执行；
- 证据等级含义：**A**=作者一手实测；**B**=官方文档或多个独立来源一致；**C**=单一来源/推断，当线索别当结论；
- 知识库欢迎带证据的补充（C→B→A 的升级通道见仓库 README）。

