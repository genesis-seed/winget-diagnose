# winget 诊断报告

- 时间：2026-10-20 13:34:10
- 工具版本：winget-diagnose v0.2（诊断工具本身由 AI 起草，知识库证据分级见 kb/errors.json _meta）

## 错误指纹

- `0x8A15002B`

## 知识库未收录（官方解码回退）

### `0x8A15002B`

```
0x8a15002b : APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
找不到适用的更新
```

> 以上来自本机 `winget error`（官方、与你的 winget 版本匹配）。若它也认不出，此码多半来自安装器自身——去该包在 winget-pkgs / 上游仓库的 issue 区搜。

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

