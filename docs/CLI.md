# 文件命令行使用说明

MoonRdiff 原生命令行支持 Windows 和 Linux。核心算法由 MoonBit 实现，文件适配使用固定版本 `moonbitlang/async@0.19.3`（Apache-2.0）。signature、delta、patch 命令均已逐块处理文件。delta 仍在内存中保留摘要与索引；当前开发版 verify 按固定 64 KiB 分块比较两个文件。默认每个输入和结果均限制为 64 MiB。Windows Server 2025 和 Ubuntu 24.04 云端 release 构建均已通过五类 128 MiB 级样本的摘要、差量和还原验收，运行时显式提高预算；不代表更大文件或所有运行环境均已验证。

## 构建与示例

使用固定工具链 `0.10.17+d971670cd`，在仓库目录执行：

```sh
moon update
moon build cmd/moonrdiff --target native
python scripts/demo.py
```

下列 Python 演示与验收脚本从完整 GitHub 仓库运行，精简 Mooncakes 源码包不包含 scripts 目录。演示脚本只生成虚构文件，通过原生命令行依次生成摘要、计算补丁、还原、校验。每次使用新的 `results/demo-*` 目录，保留全部结果。报告同时给出摘要与补丁合计大小，避免把单独补丁大小误当作首次交换成本。

性能运行可使用 `moon build cmd/moonrdiff --target native --release`，可执行文件位于 `_build/native/release/build/cmd/moonrdiff/moonrdiff.exe`。省略 `--release` 时仍生成 debug 文件，演示脚本默认使用它；完整仓库中的验收脚本可用 `python scripts/check_cli.py --profile release` 检查 release 文件。性能对照必须记录并使用相同构建模式。

## 文件命令

以下用 `moon run` 运行；构建后的独立可执行文件接受同样参数。固定工具链在 Windows 和 Linux 均输出 `_build/native/debug/build/cmd/moonrdiff/moonrdiff.exe`；Linux 的 `.exe` 文件名后缀不影响其作为原生程序执行。

```sh
moon run cmd/moonrdiff --target native -- signature old.bin old.sig --block-size 2048
moon run cmd/moonrdiff --target native -- delta old.sig new.bin update.delta --basis-size 123456
moon run cmd/moonrdiff --target native -- patch old.bin update.delta restored.bin
moon run cmd/moonrdiff --target native -- verify new.bin restored.bin
```

`--basis-size` 必须是生成摘要时的旧文件实际字节数；signature 成功时的 JSON 中会返回该值。计算端需要摘要、新文件和这个大小，无需旧文件内容。原始摘要和补丁不携带完整文件身份，不能用“成功解析”证明选对了版本。

verify 逐字节比较两个文件，适合手上有预期结果时验收。当前 GitHub 开发版每次最多读取每个文件的 64 KiB，发现差异即停止比较；长度不同也返回不匹配。两个文件均须通过普通文件、打开后类型和输入大小预算检查，比较后复查大小。返回 JSON 仍为 command、matched、expected_bytes、actual_bytes；退出码仍为 0 相同、1 不同、2 错误，不接受 --chunk-size。它不执行身份认证，也不能检测所有同大小并发修改；输入必须保持稳定。已发布 Mooncakes 0.1.1 保留原来的完整读取实现。

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

当前 GitHub 开发版的 signature、delta、patch、manifest 先在目标旁独占创建 `<输出路径>.moonrdiff-stage-<时钟值>` 目录，将数据写入其中的 data 文件。原有预演、预算和可选绑定检查仍执行；写入完成、同步并关闭文件后，通过 `rename(..., replace=false)` 发布到最终路径，移除空暂存目录后才输出成功 JSON。已有目标始终拒绝，最终禁止替换的重命名也会拒绝并发创建的目标；不会先删除或覆盖它。已发布 Mooncakes 0.1.2 仍保留原先直接创建输出文件的行为。

写入、检查、同步或发布失败时，命令返回 2、不输出成功 JSON，并保留新暂存目录及其中已有数据，错误信息给出检查路径。暂存创建失败或名称碰撞直接报错，不换位置重试。暂存目录不会递归清理，失败后由调用方检查处理。即使预演或参数检查失败，也可能留下空暂存目录，最终结果路径仍不创建。

发布已经成功、但空目录清理或结果输出失败时，命令仍返回 2，并明确报告 `Output was published; finalization failed`；最终文件可能已经完整存在，不能盲目重试或自动删除它。成功 JSON 的原字段保持不变，只有输出时机延后。

调用方必须保持输入和父目录稳定可信。同目录暂存减少跨文件系统移动问题，但本版本不保证不可信父目录下的防篡改、所有文件系统的原子性、目录落盘或断电耐久性；Windows 旧系统可能使用依赖库的 MoveFileEx 回退，Linux 不支持禁止替换重命名时直接报错。本实现没有修改 ACL、完整性标签或用户的 TEMP/TMP。

64 MiB 是单文件默认预算，总进程内存还包括多个输入、摘要索引、输出和运行时开销。提高预算不等于验证了相应的大文件能力。

Linux 的 1/16/128 MiB 合成基准已验证相同、局部修改、插入删除、随机和 gzip 数据共 15 组。128 MiB 级运行显式设为 `--max-input 536870912 --max-output 536870912`；并验证默认输入预算、仅提高输入预算时的默认输出预算会报错且不创建输出。这只是当前样本验收，不表示 512 MiB 或任意大文件已测。完整仓库中的 `docs/BENCHMARKS.md` 和 `benchmarks/2026-11-10-linux.json` 保留原始结果。随机数据可能比整文件传输更大；当前 debug 构建的摘要与差量计算显著慢于参考 rdiff。

另有 Windows/Linux 专用 128 MiB 验收，覆盖五类未绑定还原及局部修改样本的绑定还原、清单独立哈希与 CLI verify，并检查默认 verify/manifest 输入预算仍会拒绝超限文件。协议及具体提交、云端报告见完整仓库的 `docs/LARGE-FILES.md`。它是正确性与预算验收，不是跨平台性能比较；该历史运行早于分块 verify；当前开发版的有界读取不等于进程峰值内存恒定，也不扩大默认预算或已测文件大小。

## 验证

```sh
python scripts/check.py
```

包含核心库三后端检查与原生文件验收。云端 Windows/Linux 均运行默认链接防覆盖测试。本地受权限限制时，可以仅运行 `python scripts/check_cli.py --skip-links`；报告会明确标记跳过链接测试，不能把它当成完整验收。

摘要生成的工作缓冲区由块大小、读取分块和当前输出批次决定，不保留整个文件或累计摘要；这不等于对进程峰值内存作恒定数值保证。Linux CI 使用 GNU time 分别测量 4 MiB 与 32 MiB 虚构输入的原生子进程峰值 RSS，结果保存在产物中。

patch 先在有界缓冲区内检查整份补丁的格式、复制范围、输出预算和指令数，再独占创建结果文件并重放补丁。开发版第二遍读取或写入失败会保留暂存数据；0.1.2 仍可能留下不完整的新文件。这不是输入文件快照或事务发布；输入大小检查无法检测所有同大小修改。还原按需随机读取旧文件，复制和字面片段均分批写出。Linux CI 同时测量 4 MiB/32 MiB 整段复制补丁还原的峰值内存，并独立校验结果。

delta 也先扫描目标文件计算并检查完整输出预算，再独占创建结果并重放生成过程，因此目标文件读两遍。需保持输入稳定，大小检查不提供快照保证。目标读取窗口、字面数据和输出批次均有界；摘要与候选索引随块数增长。默认流式库目标预算 64 MiB，文件命令沿用 --max-input；块大小上限 1 MiB。Linux 测量报告同时记录差量计算峰值 RSS、摘要块数和输出大小，不能将其描述成与所有输入规模无关的恒定内存。

分块差量编码器另保留 256 字节至 64 KiB 的查找预筛选表，用来跳过不可能命中的整块索引查询。可能命中的窗口仍执行完整弱校验和强校验，尾块匹配及全局预算保持原语义。表的大小上限不代表进程总内存上限，也不改变随机数据可能增大补丁的事实。

## 绑定校验

```sh
moon run cmd/moonrdiff --target native -- manifest old.bin new.bin update.delta binding.json
moon run cmd/moonrdiff --target native -- patch old.bin update.delta restored.bin --manifest binding.json
```

manifest 记录三个普通文件的身份；它本身不证明补丁能还原目标，patch 的第一遍预演才验证这一关系。成功的绑定还原会返回 manifest_verified=true。清单最多 16 KiB，摘要按 64 KiB 分块读取，使用标准 BLAKE2b-256。预期结果与补丁不配对时，在预演阶段报错且不创建输出。若第二遍输入变化或写入失败，开发版保留暂存数据并报告失败（0.1.2 可能留下新结果文件）；不提供快照或事务承诺。

## 开发版分块 verify 验收

提交 2231048 已通过 Windows/Linux debug/release 完整检查及新一轮 128 MiB release 验收。Linux 4 MiB 与 32 MiB 样本的 verify 子进程峰值 RSS 分别为 3264、3584 KiB；这是两个进程的观测值，不是跨平台内存上限或前后版本性能对照。原始记录保存在完整仓库 benchmarks/verify-2026-11-11/，具体 run 和边界见 VALIDATION.md。Mooncakes 0.1.1 未随此开发版变更重新发布。
