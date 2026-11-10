# 文件命令行使用说明

MoonRdiff 原生命令行支持 Windows 和 Linux。核心算法由 MoonBit 实现，文件适配使用固定版本 `moonbitlang/async@0.19.3`（Apache-2.0）。当前完整读入文件；默认每个输入和结果均限制为 64 MiB，并非流式或大文件版本。

## 构建与示例

使用固定工具链 `0.10.17+d971670cd`，在仓库目录执行：

```sh
moon update
moon build cmd/moonrdiff --target native
python scripts/demo.py
```

演示脚本只生成虚构文件，通过原生命令行依次生成摘要、计算补丁、还原、校验。每次使用新的 `results/demo-*` 目录，保留全部结果。报告同时给出摘要与补丁合计大小，避免把单独补丁大小误当作首次交换成本。

## 四个命令

以下用 `moon run` 运行；构建后的独立可执行文件接受同样参数。Windows 输出位于 `_build/native/debug/build/cmd/moonrdiff/moonrdiff.exe`，Linux 同目录下为 `moonrdiff`。

```sh
moon run cmd/moonrdiff --target native -- signature old.bin old.sig --block-size 2048
moon run cmd/moonrdiff --target native -- delta old.sig new.bin update.delta --basis-size 123456
moon run cmd/moonrdiff --target native -- patch old.bin update.delta restored.bin
moon run cmd/moonrdiff --target native -- verify new.bin restored.bin
```

`--basis-size` 必须是生成摘要时的旧文件实际字节数；signature 成功时的 JSON 中会返回该值。计算端需要摘要、新文件和这个大小，无需旧文件内容。原始摘要和补丁不携带完整文件身份，不能用“成功解析”证明选对了版本。

verify 逐字节比较两个文件，适合手上有预期结果时验收；它不执行身份认证，也不能在没有预期文件时证明补丁可信。

## 参数与结果

| 参数 | 适用命令 | 默认值 |
| --- | --- | --- |
| `--max-input N` | 全部 | 每个输入 67108864 字节 |
| `--max-output N` | signature、delta、patch | 67108864 字节 |
| `--block-size N` | signature | 2048 字节，必须为正数 |
| `--strong-length N` | signature | 32，支持 1—32；建议保持默认 |
| `--basis-size N` | delta | 必填，非负字节数 |
| `--max-checks N` | delta | 1000000，耗尽后剩余内容采用字面数据 |

数值为非负十进制 Int32，不接受单位后缀、负数或重复选项。成功时 stdout 输出一行 JSON；错误写入 stderr。`--help` 返回使用说明。

退出码：0 表示操作成功或 verify 相同；1 表示 verify 不同；2 表示用法、格式、预算或文件读写错误。

## 文件行为

输入必须是普通文件，并在操作期间保持稳定；读前检查大小，读后确认大小未变，但不提供文件快照语义，无法检测所有同大小并发修改。

输出通过操作系统独占创建。已有路径一律拒绝，包括同名输入文件、硬链接和符号链接；没有强制覆盖开关。输入和格式验证失败时不创建结果。实际写入或同步失败时可能留下不完整的新文件，程序报告错误并保留它，供人工检查。该版本不承诺故障或断电时的事务性发布。

64 MiB 是单文件默认预算，总进程内存还包括多个输入、摘要索引、输出和运行时开销。提高预算不等于验证了相应的大文件能力。

## 验证

```sh
python scripts/check.py
```

包含核心库三后端检查与原生文件验收。云端 Windows/Linux 均运行默认链接防覆盖测试。本地受权限限制时，可以仅运行 `python scripts/check_cli.py --skip-links`；报告会明确标记跳过链接测试，不能把它当成完整验收。
