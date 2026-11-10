# MoonRdiff

纯 MoonBit 远程差量基础库，处于早期开发阶段。

目标是让备份、同步和资源更新程序通过旧文件摘要计算差量，再利用旧文件还原新版。目前实现 **RK/BLAKE2 分块摘要生成、读写，以及 rdiff 补丁格式的内存编解码原型**：编码器接收显式的复制与插入指令，解码器支持 literal/copy/end 指令及其全部参数宽度，并检查截断、范围和输出预算。

**尚未实现自动块匹配、分块输入或正式文件 CLI。当前不能作为完整远程同步库使用。**

## 构建与测试

固定依赖：`cc06b/mooncry@0.71.0`（Apache-2.0），用于 BLAKE2b-256；其他密码算法不属于 MoonRdiff 的 API。

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

脚本验证 MoonBit 显式指令补丁由 rdiff 还原，以及 rdiff 生成的补丁由 MoonBit 还原。结果保存在忽略提交的 `results/` 中。另验证摘要与 rdiff 逐字节一致、参考摘要可解析，以及 MoonBit 摘要能用于 rdiff 计算差量。MoonBit 自动差量匹配仍属于后续里程碑。

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

原创代码采用 MIT。格式参考 [librsync 格式说明](https://librsync.github.io/page_formats.html)及其公开指令定义；[librsync](https://github.com/librsync/librsync) 为 LGPL-2.1 项目，作为独立测试工具，不随包分发。本仓库不包含其代码翻译或复制的指令表。

详细范围及开发安排见 [项目计划](docs/PROJECT-PLAN.md)，当前证据见 [验证记录](docs/VALIDATION.md)。
