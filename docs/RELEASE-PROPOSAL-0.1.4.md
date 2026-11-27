# MoonRdiff 0.1.4 发布候选

`serikaonoe123/moonrdiff@0.1.4` 已按本方案获批并发布。下文保留固定的候选源码、归档和验收范围。[正式发布与安装记录](RELEASE-0.1.4.md)

## 固定源码和归档

- 固定提交为 [`2cd16710c6fd295d0a4cb22e094de318c8de9b2f`](https://github.com/serikaonoe123/moonrdiff/tree/2cd16710c6fd295d0a4cb22e094de318c8de9b2f)。
- 归档包含 34 个文件，源码共 151,585 字节。与 0.1.3 的清单相比，8 个文件内容有变化，即六个原生 CLI 文件、`moon.mod` 和包内 README。
- 原生 CLI 会继续读取正长度的短读，后续系统读取错误保留原始诊断。真正的提前 EOF 仍报告 `ReaderClosed`。库 API、rdiff 格式、默认预算和 `moonbitlang/async@0.19.3` 依赖版本保持一致。
- 候选清单保留 Linux 云端原始报告字节，SHA-256 为 `dad6071d6941f5e6131f7fbea59ba40ee32c3ef77eb8fddabadecb08ad6f099d`。[34 文件清单](../packaging/candidate-0.1.4.json)

| 候选 ZIP | 字节数 | SHA-256 |
| --- | ---: | --- |
| Linux | 55,240 | `7a56f2510fa675da5c3e9eedcc5b4205f0bcef6add0c34bdc1cd757b804c31cd` |
| Windows | 55,240 | `40e166f2ad29fb7af61dadd1777fcb834f213a2a5bb7539091ae9e686524e59a` |

## 已完成验收

下载了固定提交的两个实际 ZIP，逐文件核对路径、长度、SHA-256 和 Git 源文件。两平台是相同的 34 文件和内容，ZIP 容器哈希各自记录。各平台从解包归档通过 JS、Native、Wasm-GC 各五组公开消费者测试，并构建原生 CLI 完成带清单还原。[固定提交的双平台 CI 和归档](https://github.com/serikaonoe123/moonrdiff/actions/runs/45949881812)

候选 PR 的 128 MiB 双平台验收通过。Linux 再次验证块设备返回读错后两种 `patch` 路径的退出码、诊断和暂存结果。完整 CI 的资源缓存应用继续从 Mooncakes 安装 0.1.3，并核对原来的 34 文件。[双平台大文件验收](https://github.com/serikaonoe123/moonrdiff/actions/runs/45949850322) · [候选 PR](https://github.com/serikaonoe123/moonrdiff/pull/12)

## 发布后的验收

获批后从固定提交重新打包并按清单复核，上传该 Mooncakes 版本。独立消费者随后从注册表安装 0.1.4，对照全部 34 个文件的内容哈希，并在 Windows 和 Linux 上重跑三个后端的公开测试。发布与安装验收已完成。物理介质故障和实际断电恢复仍待验证。
