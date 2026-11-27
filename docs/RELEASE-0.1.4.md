# MoonRdiff 0.1.4 发布记录

`serikaonoe123/moonrdiff@0.1.4` 于 2026-11-27 按批准方案发布到 Mooncakes。固定源码提交是 `2cd16710c6fd295d0a4cb22e094de318c8de9b2f`。原生 CLI 会继续读取正长度的短读，后续发生系统 I/O 错误时会报告该错误。库 API、格式、默认预算和依赖版本与 0.1.3 一致。[批准的发布方案](RELEASE-PROPOSAL-0.1.4.md)

## 上传记录

从独立目录重新打包，按批准清单比对全部 34 个文件的长度、SHA-256 和固定 Git 源文件。官方 Moon CLI 完成归档解包检查，上传返回 `200 OK`，退出码为 `0`。[固定候选清单](../packaging/candidate-0.1.4.json)

上传前后的 ZIP 和从 Mooncakes 下载的 ZIP 均为 55,240 字节，SHA-256 均为 `40e166f2ad29fb7af61dadd1777fcb834f213a2a5bb7539091ae9e686524e59a`，与已验收的 Windows 候选 ZIP 一致。[候选双平台打包记录](https://github.com/serikaonoe123/moonrdiff/actions/runs/45949881812)

## 注册表安装

Windows 和 Linux 各使用独立消费者从 Mooncakes 解析 `0.1.4`，对照全部 34 个文件的内容哈希，并在 JS、Native 和 Wasm-GC 上各通过五组公开接口测试。两边都从注册表解析 `moonbitlang/async@0.19.3`。[双平台安装验收](https://github.com/serikaonoe123/moonrdiff/actions/runs/45951491168)

| 平台 | 原始报告 | 依赖解析 |
| --- | --- | --- |
| Linux | [报告](../packaging/registry-0.1.4/linux-report.json) | [解析记录](../packaging/registry-0.1.4/linux-resolution.json) |
| Windows | [报告](../packaging/registry-0.1.4/windows-report.json) | [解析记录](../packaging/registry-0.1.4/windows-resolution.json) |

应用依赖可用 `moon add serikaonoe123/moonrdiff@0.1.4` 安装。基本消费者和注册表工作流使用 0.1.4，资源缓存演示保留固定的 0.1.3 输入和安装清单。
