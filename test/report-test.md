# winget 诊断报告

- 时间：2026-10-20 13:04:21
- 工具版本：winget-diagnose v0.1（诊断工具本身由 AI 起草，知识库证据分级见 kb/errors.json _meta）

## 错误指纹

- `0X8A150008`
- `0X8A150049`
- `0X801901F7`
- `MSI-1603`
- `MSI-1618`

## 知识库匹配（按证据等级）

### `0x8A150008` APPINSTALLER_CLI_ERROR_DOWNLOAD_FAILED  **[证据等级 A]**

- 官方描述：Downloading installer failed
- 症状：安装包下载失败。中国网络环境下最常见的一类：winget 对系统代理/隧道的遵从不可靠。
- 可能原因：
  - 安装包托管在 github.com / objects.githubusercontent.com，直连被掐或超时（winget 通常不走你开的代理/隧道）
  - 安装源 CDN 临时故障
  - DNS 污染导致解析到不可达地址
- 建议动作（工具不会替你执行）：
  - 确认是哪个域下载失败：用 winget install --verbose-logs 重跑，日志里有完整 URL（见官方 troubleshooting：winget --info 可查日志路径）
  - 若托管在 github.com：临时配置可用的代理，或手动下载安装包后用 winget install --manifest 本地安装（需先 winget settings --enable LocalManifestFiles，管理员）
  - 换网络环境（手机热点）重试以区分『包的问题』还是『路的问题』
- 依据：本机实测 2026-10-18：winget install GitHub.cli 因安装包在 github.com 报 502，机器开着隧道但 winget 不走

### `MSI-1618` ERROR_INSTALL_ALREADY_RUNNING  **[证据等级 B]**

- 官方描述：winget error 1618 可本地解码
- 症状：另一个安装正在进行。
- 可能原因：
  - Windows Installer 互斥：别的 msiexec 在跑（可能是 Windows Update 或商店后台）
- 建议动作（工具不会替你执行）：
  - 等待几分钟后重试；任务管理器确认无 msiexec 进程
- 依据：Windows Installer 标准退出码

### `MSI-1603` ERROR_INSTALL_FAILURE (Windows Installer)  **[证据等级 B]**

- 官方描述：winget error 1603 可本地解码
- 症状：MSI 安装器内部致命错误。winget 会包一层 0x8A150049 MSI_INSTALL_FAILED，真实码在输出/日志里。
- 可能原因：
  - 权限不足（写 Program Files / 注册表）
  - 旧版本残留/安装中断的缓存损坏
  - 自定义 action 失败（安装器脚本层面，winget 无法控制）
- 建议动作（工具不会替你执行）：
  - 管理员重试
  - 开 MSI 详细日志：msiexec /i <pkg> /L*V <log.txt>（若能取出 MSI 参数）
  - 查 Windows Installer 自身日志 %TEMP% 下的 MSI*.LOG
- 依据：Windows Installer 标准退出码，官方 `winget error` 命令支持解码

## 知识库未收录（官方解码回退）

### `0X8A150049`

```
0x8a150049 : APPINSTALLER_CLI_ERROR_MSI_INSTALL_FAILED
运行 MSI 安装失败
```
### `0X801901F7`

```
0x801901f7
Service unavailable (503).
```

> 以上来自本机 `winget error`（官方、与你的 winget 版本匹配）。若它也认不出，此码多半来自安装器自身——去该包在 winget-pkgs / 上游仓库的 issue 区搜。

## 环境体检

| 项目 | 值 |
|------|-----|
| winget 版本 | v1.29.380 |
| 日志路径 | 日志 %LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir |
| 当前是否管理员 | 否 |
| C 盘剩余 | 29.8 GB |
| winhttp 代理 | \| Direct access (no proxy server). |
| 环境变量代理 | （未设置） |
| 已配置源 | --------------------------------------------------------------- \| msstore https://storeedgefd.dsx.mp.microsoft.com/v9.0 false \| winget https://cdn.winget.microsoft.com/cache false \| winget-font https://cdn.winget.microsoft.com/fonts true |

## 边界声明

- 本工具**只诊断、只建议**，上面所有修改类命令由你决定是否执行；
- 证据等级含义：**A**=作者一手实测；**B**=官方文档或多个独立来源一致；**C**=单一来源/推断，当线索别当结论；
- 知识库欢迎带证据的补充（C→B→A 的升级通道见仓库 README）。

