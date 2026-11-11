# MoonRdiff 0.1.0 发布方案

状态：候选材料已准备，等待首次公开发布授权。当前仅更新了 GitHub 源码与候选元数据，尚未执行 Mooncakes 上传。

## 发布对象

- 公共注册表：Mooncakes，账号命名空间 serikaonoe123。
- 模块与版本：`serikaonoe123/moonrdiff@0.1.0`，首个预 1.0 版本。
- 固定源码提交：`e09db0b71ef6386f30aa5e5aebd2a2c619013be9`。
- 固定工具链：moonc `0.10.17+d971670cd`；原生文件适配依赖 `moonbitlang/async@0.19.3`。
- 归档内容：现有 [34 文件允许清单](../packaging/files.txt)。[完整候选内容哈希与验收记录](../packaging/candidate-0.1.0.json)来自成功 Linux CI，SHA-256 为 `99cfe413492f8573d49fd63283bec8549e64588b08b57344182029f32bacb0be`。
- 许可元数据：`MIT AND Apache-2.0`；保留根许可证及第三方完整许可证、来源和修改记录。

发布范围是上述版本的 34 件源码文件，按清单中的路径、长度和 SHA-256 审核。开发脚本、探针、消费者示例、内部进度文档、基准原始数据及本方案不进入包内。

## 可审阅的实际归档

[CI 42955589065](https://github.com/serikaonoe123/moonrdiff/actions/runs/42955589065) 的专用产物名为 `package-candidate-ubuntu-24.04` 和 `package-candidate-windows-latest`。两平台均生成 50,462 字节的候选 ZIP：

| 平台 | 实际 ZIP SHA-256 |
| --- | --- |
| Linux | `ef84cdaa7dec3ad9d05ae282ae953912cc4c7712d8009c416b78a55e80bad08a` |
| Windows | `7ed929693845d10bc8f145a0c73efab83131822b97308a0d4bc796815370588b` |

两份 ZIP 已下载，全部条目分别核对了清单哈希及固定提交的原始文件字节；按路径比较的 34 件内容完全一致。ZIP 条目顺序可以不同，跨平台归档 SHA-256 不相同不表示源码不同。发布工具会打包当前模块，因此授权绑定固定提交和文件内容清单；上述 ZIP 哈希用于审阅参考，不承诺重打包字节级复现。

本地审阅副本位于 `results/release-0.1.0/serikaonoe123-moonrdiff-0.1.0.zip` 与 `candidate-package-report.json`，均为从 Linux CI 下载的实际材料。

## 已完成的验收

- 根 API 审查见 [API-REVIEW.md](API-REVIEW.md)。接口签名和预算默认值保持原样，文档已修正早期描述。
- 两平台各对提取归档的独立消费者运行 JS、Native、Wasm-GC 五组公开 API 测试，并通过归档内原生 CLI 的文件/绑定清单闭环。
- CI 全部检查、构建、核心三后端测试、Windows 77/Linux 78 项 debug 和 release CLI 验收、330 项参考互操作均通过。
- [大文件验收 42955481358](https://github.com/serikaonoe123/moonrdiff/actions/runs/42955481358)在提交 `4039d7b3d51ee943f61ae59d7f50cde4a2a44626` 上通过两平台 128 MiB 矩阵。该提交与拟发布提交的全部 34 件包内文件已逐字节核对相同；之后仅增加 CI 小型产物和发布后检查脚本。
- 保留性能收益、资源开销及计时异常；本版本不承诺快于 rdiff、所有数据都节省传输、文件快照、事务发布或发布者认证。verify 仍完整读取两个文件。

## 授权后的执行与验收

1. 从固定提交创建隔离发布目录，核对版本、工具链和 34 件文件哈希，再运行 `moon package --frozen` 审计实际内容。
2. 使用对应 Mooncakes 账号执行 `moon publish --frozen`，上传公共模块 `serikaonoe123/moonrdiff@0.1.0`。若版本已存在、登录失效或发生安全/权限拒绝，保存证据并报告，不自行更换版本或权限。
3. 用 `scripts/check_registry.py --approved-inventory PATH_TO_CANDIDATE_REPORT` 创建独立消费者，要求来源为注册表且版本恰为 0.1.0，逐项比对已安装源码与批准清单，并运行三后端各五组公开 API 测试。
4. 记录发布结果、注册表安装证据和具体失败。注册表安装验收在实际上传之前仍为待完成，不以本地工作区替代。

本次确认将授权上述 Mooncakes 上传及其发布后安装验收。此前 MoonFFI Lab 的版本发布确认属于另一模块；本方案需要 MoonRdiff 本身的首次公开发布确认。
