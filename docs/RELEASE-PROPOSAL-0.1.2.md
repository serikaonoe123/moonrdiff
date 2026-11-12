# MoonRdiff 0.1.2 补丁发布方案

状态：用户已明确批准，已按本方案发布并通过 Windows/Linux 注册表验收，见 [发布记录](RELEASE-0.1.2.md)。以下保留批准的具体范围。

## 固定内容

- 模块：`serikaonoe123/moonrdiff@0.1.2`。
- 固定源码提交：`287872c13b6f2865b3657c10d66ce6eff88cff30`。
- 归档为 34 文件，源码合计 145,485 字节。相对已发布 0.1.1，只有 README.mooncakes.md、cmd/moonrdiff/main.mbt、delta_stream_test.mbt、docs/CLI.md 和 moon.mod 的内容变化。
- 主要行为改进是原生 verify 成对读取至多 64 KiB，并保留四个 JSON 字段、退出码、默认预算和原有选项。另纳入分块完整链路回归测试与更新后的说明。
- 公共库 API、rdiff 格式、默认预算和 async@0.19.3 依赖不变。固定 MoonBit 0.10.17+d971670cd。源码归档/整文件选择演示仍只在完整 GitHub 仓库内，不进入精简包。
- [原始候选清单及报告](../packaging/candidate-0.1.2.json) SHA-256：`1156780057f1506bee8c6c587f9435369d5b0cce12db8adc80b745c8a92d68f5`。

## 实际归档与验收

[完整 CI 43156224761](https://github.com/serikaonoe123/moonrdiff/actions/runs/43156224761)、[双平台 128 MiB 验收 43156224769](https://github.com/serikaonoe123/moonrdiff/actions/runs/43156224769) 与 [已发布 0.1.1 注册表回归 43156256428](https://github.com/serikaonoe123/moonrdiff/actions/runs/43156256428) 均指向上述固定源码提交。

| 实际产物 | ZIP 大小 | ZIP SHA-256 |
| --- | ---: | --- |
| Linux | 52,740 字节 | `037e2eb43cf331f76a2d0ca1803d1e07852733ba4c0cb73396ff79bbf82871e4` |
| Windows | 52,740 字节 | `0f064d76cdbf0ad11229a6cac2059a94c48fb4de1f135667aff5dee2b9d6b47e` |

两份 ZIP 均已下载，核对归档 SHA-256、唯一的 34 文件列表、每份内容的长度/哈希以及固定 Git blob 字节。两平台按路径比较的文件内容完全相同。ZIP 元数据可不同；发布范围绑定固定源码和逐文件清单。

完整 CI 包括三个后端核心检查/测试、debug/release CLI、实际归档三个后端各五组消费者及包内文件更新流程、Linux 330 项 rdiff 互操作和内存采样。独立大文件检查覆盖两平台五类 128 MiB 样本，保留默认 verify/manifest 预算拒绝。注册表回归验证的是已发布 0.1.1，不能代替尚未发布的 0.1.2 安装验收。

本地保留实际 ZIP、报告、审计结果和官方日志于 results/release-0.1.2/。候选报告的原始字节由常规 CI 校验。方案与归档均未声称解决 D8050 根因；本机 Native 路径目前已恢复。

## 确认后的执行范围

从上述固定提交创建隔离目录，核对全部内容与声明依赖，再执行官方 moon publish 完整打包、解包及检查流程上传 0.1.2；不关闭校验。上传后再次核对最终归档，并执行使用本候选清单的独立注册表安装验收。0.1.2 未上传前不把它标记为已发布或已通过注册表安装。

本次只涉及该 Mooncakes 模块版本，不包含 GitHub Release、额外附件或其他项目。已发布 0.1.1 内容保持不变。版本已存在、内容不符或遇到安全/权限拒绝时保留证据并报告，不自行换版本或更改权限。

输入仍需保持稳定；本版本不提供文件快照、事务性输出、发布者认证或通用内存上限。
