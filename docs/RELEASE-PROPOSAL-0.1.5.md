# MoonRdiff 0.1.5 发布候选

`serikaonoe123/moonrdiff@0.1.5` 将当前仓库对 MoonBit 1.0 RC1 的适配带到 Mooncakes。原生 CLI 使用 `moonbitlang/async@0.22.11`，并迁移已弃用的字节缓冲区调用。公开库接口、rdiff 格式和许可文件沿用 0.1.4。

## 固定源码和实际归档

- 源码提交为 [14b4e004c59344aa790e618f457e170e8224427e](https://github.com/serikaonoe123/moonrdiff/tree/14b4e004c59344aa790e618f457e170e8224427e)，编译器和 core 固定为 `1.0.0-rc1+3c0520448`。
- 两平台归档均包含 34 个文件，共 151,901 字节源码。逐文件比对了归档内容、报告记录和 Git 源文件。
- 候选清单保留 Linux 原始报告，SHA-256 为 `647231e3b56e120201625933e1d6ba006e65f5505dc82cac28e5dfb5c901cf05`。[候选内容清单](../packaging/candidate-0.1.5.json)

| 候选 ZIP | 字节数 | SHA-256 |
| --- | ---: | --- |
| Linux | 55,332 | `b44173b601b0352a366b34ba39ab673c9fb7525ed90949295faa40951b8519ab` |
| Windows | 55,332 | `ba30ffecd70741bcf46d099d6c6811a4aa59dad06da1bae79f638b383d66bccd` |

## 已完成验收

Windows、Linux 均通过完整 CI。各平台从实际归档构建了原生 CLI 并完成带清单还原。解包消费者在 JS、Native 和 Wasm-GC 上各通过五项公开接口测试。本地从独立解包目录运行 release 构建，生成的命令可运行。[完整 CI 与归档](https://github.com/serikaonoe123/moonrdiff/actions/runs/46091953331)

128 MiB 大文件验收及已发布 0.1.4 的安装回归均在两平台通过。[大文件验收](https://github.com/serikaonoe123/moonrdiff/actions/runs/46091956018) · [0.1.4 安装回归](https://github.com/serikaonoe123/moonrdiff/actions/runs/46092016268)

## 发布后验收

获批后从固定提交重新打包，核对 Windows ZIP 和 34 个文件的清单，再用官方 Moon CLI 上传。发布后在 Windows 和 Linux 从 Mooncakes 安装 0.1.5，核对全部文件哈希，重跑三个后端的库测试，并从注册表下载的源码独立构建原生 release CLI。
