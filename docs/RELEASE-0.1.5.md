# MoonRdiff 0.1.5 发布记录

`serikaonoe123/moonrdiff@0.1.5` 于 2026-11-28 从固定提交 `14b4e004c59344aa790e618f457e170e8224427e` 发布。发布包使用 MoonBit `1.0.0-rc1+3c0520448` 验收，原生 CLI 依赖 `moonbitlang/async@0.22.11`。[Mooncakes](https://mooncakes.io/docs/serikaonoe123/moonrdiff@0.1.5) · [发布方案](RELEASE-PROPOSAL-0.1.5.md)

上传前逐一核对了 34 个文件和 Git 源文件。官方 Moon CLI 对解包源码运行检查并返回 `200 OK`。上传前后的 ZIP 和从 Mooncakes 下载的 ZIP 均为 55,332 字节，SHA-256 均为 `ba30ffecd70741bcf46d099d6c6811a4aa59dad06da1bae79f638b383d66bccd`。[内容清单](../packaging/candidate-0.1.5.json)

Windows 和 Linux 各自从 Mooncakes 解析并下载该版本，核对全部 34 个文件的哈希。两边都在 JS、Native、Wasm-GC 上各通过五组库测试，并从独立复制的注册表源码构建了原生 release CLI。[双平台安装与构建验收](https://github.com/serikaonoe123/moonrdiff/actions/runs/46092589929)

| 平台 | 验收报告 | 依赖解析 |
| --- | --- | --- |
| Linux | [报告](../packaging/registry-0.1.5/linux-report.json) | [解析记录](../packaging/registry-0.1.5/linux-resolution.json) |
| Windows | [报告](../packaging/registry-0.1.5/windows-report.json) | [解析记录](../packaging/registry-0.1.5/windows-resolution.json) |

在 MoonBit 应用目录运行 `moon add serikaonoe123/moonrdiff@0.1.5` 安装库。要构建原生 CLI，在提取的发布包目录运行 `moon build cmd/moonrdiff --target native --release --deny-warn`。[快速验收](ACCEPTANCE.md#moonbit-10-rc1-快速验收)
