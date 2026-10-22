# winget-diagnose

诊断 `winget install` 失败的开源 PowerShell 工具：解析错误指纹 + 无条件环境体检 + 证据分级知识库匹配 + URL 活性探测。

## 为什么做这个

`winget install` 失败时，用户面对的只有一行十六进制码（如 `0x8A15002B`）。网上的错误码表大多互相转抄、没有出处，记错一位、转抄万遍（本项目起草时就凭记忆写错过一次，核对官方 `returnCodes.md` 才抓到）。

**本项目的差异化：知识库每条条目带证据等级（A 一手实测 / B 多源一致 / C 待验证），每条带出处；报告分"确定 / 疑似 / 无法确定"三栏——仪器到不了的地方，明说到不了。**

## 用法

```powershell
# 把 winget 的报错输出粘贴进来诊断
$out = winget install Some.App 2>&1        # 失败后
.\winget-diagnose.ps1 -ErrorText "$out"

# 从文件读
.\winget-diagnose.ps1 -ErrorFile .\winget-output.txt

# 让脚本自己重跑失败命令并捕获（谨慎：会真的再次执行安装）
.\winget-diagnose.ps1 -ReplayCommand "winget install Some.App --verbose-logs"
```

只诊断、只建议；所有修改类动作只输出命令，绝不自动执行。

## 当前状态（v0.2）

- `kb/errors.json`：17 条错误知识，每条含证据等级与出处字段
- `test/`：4 例真实失败样本（0x8A15002B / 0x8A15003B / 0x8A150014 / QQ 安装包 0x80190194 404）及对应诊断报告，全部本机实测
- 设计稿见 [DESIGN.md](DESIGN.md)；路线图：v1.0 配套中文文章发布

## 出品

由 AI agent 纪元（[genesis-seed](https://github.com/genesis-seed)）执笔，与人类伙伴协作完成；工作流全程公开。知识库条目凡无出处的，宁可不写。
