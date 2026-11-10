# 文件命令行使用说明

MoonRdiff 原生命令行支持 Windows 和 Linux。核心算法由 MoonBit 实现，文件适配使用固定版本 `moonbitlang/async@0.19.3`（Apache-2.0）。signature、delta、patch 命令均已逐块处理文件。delta 仍在内存中保留摘要与索引；verify 仍完整读入两个文件。默认每个输入和结果均限制为 64 MiB，尚未完成大文件验收。

## 构建与示例

使用固定工具链 `0.10.17+d971670cd`，在仓库目录执行：

```sh
moon update
moon build cmd/moonrdiff --target native
python scripts/demo.py
```

演示脚本只生成虚构文件，通过原生命令行依次生成摘要、计算补丁、还原、校验。每次使用新的 `results/demo-*` 目录，保留全部结果。报告同时给出摘要与补丁合计大小，避免把单独补丁大小误当作首次交换成本。

## 四个命令

以下用 `moon run` 运行；构建后的独立可执行文件接受同样参数。固定工具链在 Windows 和 Linux 均输出 `_build/native/debug/build/cmd/moonrdiff/moonrdiff.exe`；Linux 的 `.exe` 文件名后缀不影响其作为原生程序执行。

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
| `--block-size N` | signature | 2048 字节，支持 1—1048576 |
| `--chunk-size N` | signature、delta、patch | 65536 字节，支持 1—65536 |
| `--strong-length N` | signature | 32，支持 1—32；建议保持默认 |
| `--max-instructions N` | patch | 1000000，超过报错 |
| `--basis-size N` | delta | 必填，非负字节数 |
| `--max-checks N` | delta | 1000000，耗尽后剩余内容采用字面数据 |

数值为非负十进制 Int32，不接受单位后缀、负数或重复选项。成功时 stdout 输出一行 JSON；错误写入 stderr。`--help` 返回使用说明。

退出码：0 表示操作成功或 verify 相同；1 表示 verify 不同；2 表示用法、格式、预算或文件读写错误。

## 文件行为

输入必须是普通文件，并在操作期间保持稳定；读前检查大小，读后确认大小未变，但不提供文件快照语义，无法检测所有同大小并发修改。

输出通过操作系统独占创建。已有路径一律拒绝，包括同名输入文件、硬链接和符号链接；没有强制覆盖开关。已知参数、大小预算或格式验证失败时不创建结果。分块摘要读取、实际写入或同步失败时可能留下不完整的新文件，程序报告错误并保留它，供人工检查。该版本不承诺故障或断电时的事务性发布。

64 MiB 是单文件默认预算，总进程内存还包括多个输入、摘要索引、输出和运行时开销。提高预算不等于验证了相应的大文件能力。

## 验证

```sh
python scripts/check.py
```

包含核心库三后端检查与原生文件验收。云端 Windows/Linux 均运行默认链接防覆盖测试。本地受权限限制时，可以仅运行 `python scripts/check_cli.py --skip-links`；报告会明确标记跳过链接测试，不能把它当成完整验收。

摘要生成的工作缓冲区由块大小、读取分块和当前输出批次决定，不保留整个文件或累计摘要；这不等于对进程峰值内存作恒定数值保证。Linux CI 使用 GNU time 分别测量 4 MiB 与 32 MiB 虚构输入的原生子进程峰值 RSS，结果保存在产物中。

patch 先在有界缓冲区内检查整份补丁的格式、复制范围、输出预算和指令数，再独占创建结果文件并重放补丁。第二遍读取或写入失败仍可能留下不完整的新文件。这不是输入文件快照或事务发布；输入大小检查无法检测所有同大小修改。还原按需随机读取旧文件，复制和字面片段均分批写出。Linux CI 同时测量 4 MiB/32 MiB 整段复制补丁还原的峰值内存，并独立校验结果。

delta 也先扫描目标文件计算并检查完整输出预算，再独占创建结果并重放生成过程，因此目标文件读两遍。需保持输入稳定，大小检查不提供快照保证。目标读取窗口、字面数据和输出批次均有界；摘要与候选索引随块数增长。默认流式库目标预算 64 MiB，文件命令沿用 --max-input；块大小上限 1 MiB。Linux 测量报告同时记录差量计算峰值 RSS、摘要块数和输出大小，不能将其描述成与所有输入规模无关的恒定内存。
