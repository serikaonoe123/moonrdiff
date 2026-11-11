# MoonRdiff 0.1.0 发布记录

`serikaonoe123/moonrdiff@0.1.0` 已于 2026-11-11 公开发布到 Mooncakes。用户按具体方案明确批准后，从固定提交 `e09db0b71ef6386f30aa5e5aebd2a2c619013be9` 创建隔离目录进行发布。包内 34 件源码文件与批准的 [候选清单](../packaging/candidate-0.1.0.json) 一致，合计 136,068 字节。上传命令返回 exit 0、服务端 `200 OK`。

## 发布与原生校验

固定 MoonBit `0.10.17+d971670cd`，核对注册表依赖恰为 async@0.19.3，检查实际 ZIP 中每件文件的 SHA-256。最初 `moon publish --frozen` 因官方发布器新建的解包校验目录尚未安装依赖而在上传前退出；没有成功上传。单独提取批准 ZIP，使用正常依赖解析验证其仍为 async@0.19.3 后，改用官方 `moon publish` 完整打包、解包、检查流程，所有检查通过后服务端接受上传。上传包再次核对了全部批准内容；没有关闭解包检查、变更权限、切换版本或改动批准的源码内容。

发布过程原始日志和预检查记录保存在本地 results/release-0.1.0/。初次冻结校验失败也保留，后一次成功覆盖的是状态记录，不删除原始失败日志。

## 注册表独立安装验收

[Registry consumer acceptance 42957052963](https://github.com/serikaonoe123/moonrdiff/actions/runs/42957052963) 在 Windows/Linux 上均成功：新建独立消费者，没有建立 MoonRdiff 本地工作区成员；解析来源必须为 registry、版本必须为 0.1.0；安装后逐件核对 34 件源码与批准清单；JS、Native、Wasm-GC 各五组公开 API 测试全部通过。

原始报告和来源解析记录已下载并核对官方日志，按原字节归档，并纳入日常 CI 哈希审计：

| 平台 | 安装报告 | 来源解析记录 |
| --- | --- | --- |
| Windows | [report](../packaging/registry-0.1.0/windows-report.json) | [resolution](../packaging/registry-0.1.0/windows-resolution.json) |
| Linux | [report](../packaging/registry-0.1.0/linux-report.json) | [resolution](../packaging/registry-0.1.0/linux-resolution.json) |

本地第一次安装检查在读取来源树后尚未触发源文件安装，检查脚本已补充正常 moon check 下载步骤。第二次实际下载的 34 件源码与批准清单完全一致，JS 五组通过；本机 Native 仍出现 MSVC D8050 调试记录错误，保留在 results/registry-f4ed0fa8192c4a1cb0978b91316b472c/，未通过更改权限或编译标志重试。完整三后端结果来自上述两平台云端安装验收，不把云端通过描述成本机编译环境已修好。

## 使用与已知限制

在应用的 moon.mod import 块中加入 `"serikaonoe123/moonrdiff@0.1.0"`，然后运行 `moon check --target js` 安装并检查。应用的 moon.pkg 导入 root package；完整示例见 [独立消费者](../examples/consumer/consumer_test.mbt)。编译器基线、默认预算和生命周期见 FORMAT.md / CLI.md。

0.1.0 的包内 README 首段保留了发布前的候选措辞，这是本次文案遗漏；实际已发布和安装的证据以本记录及注册表来源报告为准。0.1.0 已批准包内容保持原样，文案已由用户另行批准的 [0.1.1 维护版本](RELEASE-0.1.1.md)修正并通过注册表验收。

本版本保留既有范围：raw rdiff 不认证发布者、输入需稳定、第二遍失败可能留下部分新文件，verify 仍完整读入两份文件；不承诺事务发布、任意大文件或快于 rdiff。首次发布与跨平台注册表验收已完成，后续维护可继续处理本机 Native 环境、文案修订和真实应用接入。
