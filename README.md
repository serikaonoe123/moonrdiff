# MoonRdiff

纯 MoonBit 远程差量基础库，处于早期开发阶段。

已发布到 Mooncakes：`serikaonoe123/moonrdiff@0.1.2`，见 [发布及注册表安装验收记录](docs/RELEASE-0.1.2.md)。当前进度见 [状态清单](docs/STATUS.md)，归档内容见 [打包验收](docs/PACKAGING.md)，性能方法与实测记录见 [基准说明](docs/BENCHMARKS.md)。

在应用的 `moon.mod` 的 `import` 块中加入 `"serikaonoe123/moonrdiff@0.1.2"`，然后运行 `moon check --target js` 安装并检查。包别名配置与使用代码见下方库示例；[独立消费者](examples/consumer/consumer_test.mbt)已从注册表在 Windows/Linux 的三个后端验收。

原生性能运行建议用 `moon build cmd/moonrdiff --target native --release`，执行文件在 `_build/native/release/build/cmd/moonrdiff/moonrdiff.exe`。最新同机、同为 release 的三次采样中，128 MiB 随机目标的差量耗时从 8.74 秒降到 3.80 秒（约减少 56.5%），压缩样本约减少 28%。这来自最多 64 KiB 的查找预筛选表，输出字节保持一致；随机补丁仍比整文件传输大，命令仍慢于参考 rdiff。报告保留其他场景的小幅退化及计时异常。

目标是让备份、同步和资源更新程序通过旧文件摘要计算差量，再利用旧文件还原新版。目前实现 **RK/BLAKE2 分块摘要生成、读写，自动差量匹配，以及 rdiff 补丁格式的内存编解码**；支持从旧文件摘要与新文件自动生成补丁，也保留显式指令编码接口。解码器支持 literal/copy/end 指令及其全部参数宽度，并检查截断、范围和输出预算。

**已提供 Windows/Linux 原生文件命令行；摘要生成、差量计算和补丁还原已支持分块文件处理；差量计算仍需把摘要及其索引放在内存中。**

## 构建与测试

BLAKE2b-256 复用自 `cc06b/mooncry@0.71.0` 的最小修正版，保留 Apache-2.0 许可、来源与修改记录，见 [第三方说明](third_party/mooncry_blake2/NOTICE.md)。其整块边界修复经过 Python hashlib 与 rdiff 对照验证；当前无需外部注册表依赖。

原生文件 CLI 另使用 `moonbitlang/async@0.19.3`（Apache-2.0），从官方注册表安装。

固定环境：MoonBit `0.10.17+d971670cd`，Node.js 22，测试辅助 Python 3.12+。

```sh
moon update
python scripts/check.py
moon run cmd/probe --target js -- encode-fixture
```

`cmd/probe` 仅供兼容试验，以十六进制交换小样本，并非产品命令行接口。

Linux 安装参考工具 rdiff 2.3.4 后：

```sh
python scripts/interop.py
```

脚本验证 MoonBit 显式指令补丁由 rdiff 还原，以及 rdiff 生成的补丁由 MoonBit 还原。结果保存在忽略提交的 `results/` 中。另验证摘要与 rdiff 逐字节一致、参考摘要可解析，以及 MoonBit 摘要能用于 rdiff 计算差量。自动匹配测试在不含旧文件的发送端目录执行，覆盖两种摘要来源、两种补丁生成器和两种还原器。

## 库示例

```moonbit
let delta = @rdiff.encode([
  @rdiff.Copy(offset=6, length=5),
  @rdiff.Literal(b"!"),
  @rdiff.Copy(offset=0, length=5),
])
let restored = @rdiff.patch(b"hello world", delta, max_output=11)
// restored == b"world!hello"
```

导入模块 `serikaonoe123/moonrdiff` 为 `@rdiff`；上述函数会抛出 `DeltaError`，由调用者处理。Mooncakes 依赖版本为 `0.1.2`。

单个长度、偏移和输出预算上限为 Int32 正数范围，同时受实际后端可分配内存限制。格式中的更大整数会明确报错；内存便利接口会持有传入的数据，分块接口的缓冲与索引行为见下文。严格拒绝 end 后的多余数据。

## 参考与许可

原创代码采用 MIT；`third_party/mooncry_blake2/` 保留 Apache-2.0 许可。格式参考 [librsync 格式说明](https://librsync.github.io/page_formats.html)及其公开指令定义；[librsync](https://github.com/librsync/librsync) 为 LGPL-2.1 项目，作为独立测试工具，不随包分发。本仓库不包含其代码翻译或复制的指令表。

详细范围及开发安排见 [项目计划](docs/PROJECT-PLAN.md)，当前证据见 [验证记录](docs/VALIDATION.md)。

## 自动差量匹配

调用 `parse_signature` 读取摘要，再调用 `delta(signature, target, basis_size=旧文件字节数)`。计算端只需摘要、新文件和调用方提供的旧文件大小。默认最多比较 1,000,000 个候选，达到上限后改用字面数据；默认补丁上限 16 MiB，超过则报错。

块数与旧文件大小必须一致，但这不能证明摘要来自正确文件。生产集成还需绑定旧文件和预期结果的可信摘要；建议保留默认 32 字节强校验。当前不承诺所有数据都能缩小，重复块选择与预算可能影响补丁大小。

## 文件命令行

实际集成流程见 [源码归档更新示例](docs/SOURCE-UPDATE.md)：从两个固定 Git 提交生成 TAR/ZIP，完成摘要、差量、绑定还原和校验，并报告计入摘要与清单的传输量。

见 [文件命令行使用说明](docs/CLI.md)。执行 `moon build cmd/moonrdiff --target native` 后，可运行 `python scripts/demo.py` 完成虚构数据的摘要、补丁、还原及逐字节校验。已有输出一律拒绝覆盖，默认每个输入和结果限制为 64 MiB。

## 分块摘要接口

`SignatureEncoder::new()` 创建编码器，逐次调用 `push(chunk)` 并消费返回的新增摘要字节，输入结束后调用一次 `finish()`。单次输入最多 64 KiB，块大小最多 1 MiB；编码器只保留当前未满的数据块。调用方必须及时处理返回数据，累计所有输出仍会占用相应内存。错误后编码器不可继续使用。文件命令可用 `--chunk-size N` 调整读取分块。

## 分块补丁接口

`PatchDecoder::new(basis_size=..., max_output=...)` 接收最多 64 KiB 的 `push(chunk)`，返回字面数据片段和旧文件复制请求。调用者消费每批结果并提供旧文件随机读取；最后必须调用 `finish()` 检查截断。它不累计整个结果。文件 patch 命令会先做一遍格式检查，再创建新输出并重放补丁；输入必须保持稳定。

## 分块差量接口

`DeltaEncoder::new(signature, basis_size=...)` 接收最多 64 KiB 的 `push(chunk)`，调用者消费每批补丁字节并在输入结束时调用一次 `finish()`。输入分块不改变补丁字节；长字面数据按固定 64 KiB 批次编码，可能与内存接口生成不同但兼容的补丁。块大小上限 1 MiB，索引内存随摘要块数增长。全局比较、目标字节和输出字节预算不会在分块之间重置。

## 文件绑定清单

可先运行 `manifest BASIS TARGET DELTA binding.json`，再给 `patch` 添加 `--manifest binding.json`。旧文件、补丁及还原字节流必须满足清单的大小和 BLAKE2b-256 摘要；不指定清单时保留原始 rdiff 兼容模式。清单的来源必须可信：它检测版本用错或内容损坏，不认证发布者。当前生成清单需要同时访问这三个文件，适合离线更新包准备；详见 [绑定清单规范](docs/BINDING.md)。
