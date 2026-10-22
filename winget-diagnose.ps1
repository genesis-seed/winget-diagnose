<#
.SYNOPSIS
    winget-diagnose v0.2 —— 诊断 winget 安装失败：解析错误码 + 环境体检 + 证据分级知识库匹配 + URL 活性探测。

.DESCRIPTION
    设计原则（见 DESIGN.md）：
      1. 只诊断、只建议；所有修改类动作输出命令，绝不自动执行。
      2. 知识库每条带证据等级 A(一手实测)/B(官方或多源)/C(待验证)，报告如实标注。
      3. 知识库未收录的码，回退调用 `winget error <code>` 取官方描述（本地生成、版本匹配）。
      4. 报告分三栏：确定 / 疑似 / 无法确定 —— 仪器到不了的地方明说到不了。

.EXAMPLE
    # 把 winget 的报错输出粘贴进来诊断
    winget install Some.App   # 失败后
    $out = winget install Some.App 2>&1
    .\winget-diagnose.ps1 -ErrorText "$out"

.EXAMPLE
    # 让脚本自己重跑失败命令并捕获（谨慎：会真的再次执行安装）
    .\winget-diagnose.ps1 -ReplayCommand "winget install Some.App --verbose-logs"

.EXAMPLE
    # 从文件读
    .\winget-diagnose.ps1 -ErrorFile .\winget-output.txt
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string]$ErrorText,

    [string]$ErrorFile,

    [string]$ReplayCommand,

    [string]$KBPath,

    [string]$OutFile
)

# ---------------------------------------------------------------- helpers
function Write-Step([string]$msg) { Write-Host "[diagnose] $msg" -ForegroundColor DarkCyan }

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 从自由文本里提取错误指纹
function Get-ErrorFingerprints([string]$text) {
    $found = [ordered]@{}
    if (-not $text) { return $found }

    # winget 家族 HRESULT：0x8A1500xx
    foreach ($m in [regex]::Matches($text, '0x8A15[0-9A-Fa-f]{4}')) { $found[$m.Value.ToUpper()] = $true }
    # WinHTTP 映射的 HTTP 状态：0x8019xxxx
    foreach ($m in [regex]::Matches($text, '0x8019[0-9A-Fa-f]{4}')) { $found[$m.Value.ToUpper()] = $true }
    # Store/Commerce：0x80D0xxxx
    foreach ($m in [regex]::Matches($text, '0x80D0[0-9A-Fa-f]{4}')) { $found[$m.Value.ToUpper()] = $true }
    # MSI 经典退出码（词边界匹配，避免抓到无关数字）
    foreach ($m in [regex]::Matches($text, '\b(1602|1603|1618|1638|3010)\b')) { $found["MSI-$($m.Value)"] = $true }
    # 退出码十进制 HRESULT（v0.2 实测：winget install/upgrade 的控制台文本常不含码，码只在退出码里）
    # 注意：PS5.1 中 0xFFFFFFFF 字面量是 int32(-1)，直接 -band 不会截 32 位（会符号扩展出 0xFFFFFFFF8A150014），
    # 必须用 [uint32]::MaxValue（此 bug 由真实失败回放发现，合成样本测不出——见 DESIGN.md v0.2 工程笔记）
    foreach ($m in [regex]::Matches($text, 'EXITCODE:\s*(-?\d{9,11})')) {
        $hex = '0x{0:X8}' -f [uint32]([int64]$m.Groups[1].Value -band [uint32]::MaxValue)
        if ($hex -match '^0x(8A15|8019|80D0)') { $found[$hex] = $true }
    }

    return $found
}

# ---------------------------------------------------------------- input
if ($ReplayCommand) {
    Write-Step "Replay 模式：将执行并捕获「$ReplayCommand」的输出与退出码"
    Write-Host "  （该命令会真实执行。Ctrl+C 取消。）"
    Start-Sleep -Seconds 2
    $script:ErrorText = (Invoke-Expression $ReplayCommand 2>&1 | Out-String)
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        # v0.2：控制台文本常不含错误码，把退出码转成十六进制指纹一并喂入
        $hex = '0x{0:X8}' -f [uint32]([int64]$LASTEXITCODE -band [uint32]::MaxValue)
        $script:ErrorText += "`nEXITCODE:$LASTEXITCODE ($hex)"
    }
}
elseif ($ErrorFile) {
    Write-Step "从文件读取报错输出：$ErrorFile"
    $script:ErrorText = Get-Content $ErrorFile -Raw
}
elseif (-not $ErrorText) {
    Write-Host "粘贴 winget 的报错输出，结束输入按回车（或用 -ErrorText / -ErrorFile / -ReplayCommand）："
    $lines = @()
    while ($true) { $l = Read-Host; if ([string]::IsNullOrWhiteSpace($l)) { break }; $lines += $l }
    $script:ErrorText = ($lines -join "`n")
}

# ---------------------------------------------------------------- KB
if (-not $KBPath) { $KBPath = Join-Path $PSScriptRoot "kb\errors.json" }
$KB = Get-Content $KBPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Step ("知识库 v{0}，{1} 条（A:{2} B:{3} C:{4}）" -f $KB._meta.version,
    $KB.entries.Count,
    @($KB.entries | Where-Object evidence -eq 'A').Count,
    @($KB.entries | Where-Object evidence -eq 'B').Count,
    @($KB.entries | Where-Object evidence -eq 'C').Count)

# ---------------------------------------------------------------- 1) 错误指纹匹配
$fingerprints = Get-ErrorFingerprints $script:ErrorText
$matched   = @()   # 知识库命中
$unknown   = @()   # 知识库未命中 → 官方解码回退

foreach ($code in $fingerprints.Keys) {
    $entry = $KB.entries | Where-Object { $_.code -eq $code } | Select-Object -First 1
    if ($entry) { $matched += $entry }
    else        { $unknown += $code }
}

# ---------------------------------------------------------------- 2) 环境体检（无条件执行）
Write-Step "环境体检……"
$env_checks = [ordered]@{}

try { $env_checks['winget 版本']   = (winget --version 2>&1 | Out-String).Trim() }
catch { $env_checks['winget 版本'] = "获取失败：$_" }

try {
    $info = (winget --info 2>&1 | Out-String)
    $logLine = ($info -split "`n" | Where-Object { $_ -match 'Logs|日志' } | Select-Object -First 1)
    $env_checks['日志路径'] = if ($logLine) { $logLine.Trim() } else { '（见 winget --info 输出）' }
}
catch { $env_checks['日志路径'] = "获取失败：$_" }

$env_checks['当前是否管理员'] = if (Test-IsAdmin) { '是' } else { '否' }

try {
    $free = (Get-PSDrive C).Free / 1GB
    $env_checks['C 盘剩余'] = ('{0:N1} GB' -f $free)
}
catch { $env_checks['C 盘剩余'] = "获取失败：$_" }

try { $env_checks['winhttp 代理'] = ((netsh winhttp show proxy 2>&1 | Out-String).Trim() -split "`n" | Select-Object -Skip 1) -join ' | ' }
catch { $env_checks['winhttp 代理'] = "获取失败：$_" }

$env_checks['环境变量代理'] = @(
    if ($env:HTTP_PROXY)  { "HTTP_PROXY=$($env:HTTP_PROXY)" }
    if ($env:HTTPS_PROXY) { "HTTPS_PROXY=$($env:HTTPS_PROXY)" }
) -join ' ' -replace '^$', '（未设置）'

try {
    $src = (winget source list 2>&1 | Out-String).Trim()
    $env_checks['已配置源'] = ($src -split "`n" | Select-Object -Skip 1) -join ' | '
}
catch { $env_checks['已配置源'] = "获取失败：$_" }

try {
    # v0.2：LocalManifestFiles 开关状态（读设置文件，只读不改；默认关闭时文件可能不存在或无此键）
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $settingsPath) {
        $st = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $lmf = $st.experimentalFeatures.LocalManifestFiles
        $env_checks['LocalManifestFiles'] = if ($null -ne $lmf) { "$lmf" } else { '未设置（默认关闭）' }
    } else {
        $env_checks['LocalManifestFiles'] = '未设置（settings.json 不存在，默认关闭）'
    }
}
catch { $env_checks['LocalManifestFiles'] = "读取失败：$_" }

# v0.2：从报错文本提取 URL 并探测（HEAD，15s 超时）——验证下载地址是死是活、错误是否当场复现
$urls = [regex]::Matches($script:ErrorText, 'https?://[^\s\u3000-\u9FFF，。）]+') | ForEach-Object { $_.Value.TrimEnd('.', ')') } | Select-Object -Unique
$url_probes = @()
foreach ($u in ($urls | Select-Object -First 3)) {
    $status = curl.exe -sI --max-time 15 -o NUL -w "%{http_code}" $u 2>$null
    $url_probes += "$u → HTTP $status"
}
if ($url_probes.Count -gt 0) { $env_checks['报错中 URL 探测'] = $url_probes -join ' ; ' }

# ---------------------------------------------------------------- 3) 生成报告
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutFile) { $OutFile = Join-Path (Get-Location) "winget-diagnosis-$stamp.md" }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# winget 诊断报告")
[void]$sb.AppendLine()
[void]$sb.AppendLine("- 时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("- 工具版本：winget-diagnose v0.2（诊断工具本身由 AI 起草，知识库证据分级见 kb/errors.json `_meta`）")
[void]$sb.AppendLine()
[void]$sb.AppendLine("## 错误指纹")
if ($fingerprints.Count -eq 0) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**未从输入中识别到错误码。** 可能原因：输出不完整、错误是纯文本（如 `No package found matching input criteria`）、或安装器自定义退出码。")
    [void]$sb.AppendLine("建议用 `winget install <pkg> --verbose-logs` 重跑后把完整输出带日志再诊（日志路径见下方环境体检）。")
} else {
    [void]$sb.AppendLine()
    foreach ($k in $fingerprints.Keys) { [void]$sb.AppendLine("- ``$k``") }
}

if ($matched.Count -gt 0) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## 知识库匹配（按证据等级）")
    foreach ($e in ($matched | Sort-Object { [int](@{A=0;B=1;C=2}[$_.evidence]) })) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("### ``$($e.code)`` $([string]$e.symbol)  **[证据等级 $($e.evidence)]**")
        [void]$sb.AppendLine()
        if ($e.official) { [void]$sb.AppendLine("- 官方描述：$($e.official)") }
        [void]$sb.AppendLine("- 症状：$($e.symptom)")
        [void]$sb.AppendLine("- 可能原因：")
        foreach ($c in $e.causes) { [void]$sb.AppendLine("  - $c") }
        [void]$sb.AppendLine("- 建议动作（工具不会替你执行）：")
        foreach ($a in $e.actions) { [void]$sb.AppendLine("  - $a") }
        [void]$sb.AppendLine("- 依据：$($e.source)")
    }
}

if ($unknown.Count -gt 0) {
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("## 知识库未收录（官方解码回退）")
    [void]$sb.AppendLine()
    foreach ($code in $unknown) {
        [void]$sb.AppendLine("### ``$code``")
        [void]$sb.AppendLine()
        $official = winget error $code 2>&1 | Out-String
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine($official.Trim())
        [void]$sb.AppendLine('```')
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("> 以上来自本机 ``winget error``（官方、与你的 winget 版本匹配）。若它也认不出，此码多半来自安装器自身——去该包在 winget-pkgs / 上游仓库的 issue 区搜。")
}

[void]$sb.AppendLine()
[void]$sb.AppendLine("## 环境体检")
[void]$sb.AppendLine()
[void]$sb.AppendLine("| 项目 | 值 |")
[void]$sb.AppendLine("|------|-----|")
foreach ($k in $env_checks.Keys) {
    $v = ("$($env_checks[$k])" -replace '\|', '\|' -replace '\s+', ' ').Trim()
    [void]$sb.AppendLine("| $k | $v |")
}

[void]$sb.AppendLine()
[void]$sb.AppendLine("## 边界声明")
[void]$sb.AppendLine()
[void]$sb.AppendLine("- 本工具**只诊断、只建议**，上面所有修改类命令由你决定是否执行；")
[void]$sb.AppendLine("- 证据等级含义：**A**=作者一手实测；**B**=官方文档或多个独立来源一致；**C**=单一来源/推断，当线索别当结论；")
[void]$sb.AppendLine("- 知识库欢迎带证据的补充（C→B→A 的升级通道见仓库 README）。")

$sb.ToString() | Set-Content $OutFile -Encoding UTF8
Write-Step "报告已写入：$OutFile"
Get-Content $OutFile -Encoding UTF8 | Write-Host
