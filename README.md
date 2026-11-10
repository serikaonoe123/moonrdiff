# MoonRdiff

纯 MoonBit 远程差量基础库，处于早期开发阶段。

目标是让备份、同步和资源更新程序通过旧文件摘要计算差量，再利用旧文件还原新版。目前实现 **RK/BLAKE2 分块摘要生成、读写，自动差量匹配，以及 rdiff 补丁格式的内存编解码**；支持从旧文件摘要与新文件自动生成补丁，也保留显式指令编码接口。解码器支持 literal/copy/end 指令及其全部参数宽度，并检查截断、范围和输出预算。

**已提供 Windows/Linux 原生文件命令行；当前仍完整读入文件，分块输入尚未实现。**

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

导入模块 `serikaonoe123/moonrdiff` 为 `@rdiff`；上述函数会抛出 `DeltaError`，由调用者处理。尚未发布 Mooncakes 包。

首版原型的单个长度、偏移和输出预算上限为 Int32 正数范围，同时受实际后端可分配内存限制。格式中的更大整数会明确报错；本阶段整个输入输出均驻留内存。严格拒绝 end 后的多余数据。

## 参考与许可

原创代码采用 MIT；`third_party/mooncry_blake2/` 保留 Apache-2.0 许可。格式参考 [librsync 格式说明](https://librsync.github.io/page_formats.html)及其公开指令定义；[librsync](https://github.com/librsync/librsync) 为 LGPL-2.1 项目，作为独立测试工具，不随包分发。本仓库不包含其代码翻译或复制的指令表。

详细范围及开发安排见 [项目计划](docs/PROJECT-PLAN.md)，当前证据见 [验证记录](docs/VALIDATION.md)。

## 自动差量匹配

调用 `parse_signature` 读取摘要，再调用 `delta(signature, target, basis_size=旧文件字节数)`。计算端只需摘要、新文件和调用方提供的旧文件大小。默认最多比较 1,000,000 个候选，达到上限后改用字面数据；默认补丁上限 16 MiB，超过则报错。

块数与旧文件大小必须一致，但这不能证明摘要来自正确文件。生产集成还需绑定旧文件和预期结果的可信摘要；建议保留默认 32 字节强校验。当前不承诺所有数据都能缩小，重复块选择与预算可能影响补丁大小。

## 文件命令行

见 [文件命令行使用说明](docs/CLI.md)。执行 `moon build cmd/moonrdiff --target native` 后，可运行 `python scripts/demo.py` 完成虚构数据的摘要、补丁、还原及逐字节校验。已有输出一律拒绝覆盖，默认每个输入和结果限制为 64 MiB。
