# MoonRdiff 0.1.1 文档补丁发布方案

状态：用户已明确批准，0.1.1 已按固定提交/内容清单发布并通过两平台注册表安装验收，见 [发布记录](RELEASE-0.1.1.md)。下文保留本次批准的具体范围。

## 固定发布内容

- 公共模块：`serikaonoe123/moonrdiff@0.1.1`。
- 固定提交：`9ed7e11ea5f298a1ba3877a8932f54e8d8bd1200`。
- 仍为 34 件文件，源码合计 135,990 字节；相对已批准 0.1.0 清单，只有 `README.mooncakes.md` 与 `moon.mod` 的内容哈希改变。
- README 移除会在发布后过期的“候选、尚未发布、注册表待验收”措辞，改为描述功能并指向分版本发布记录。module version 改为 0.1.1。
- API、算法、默认预算、文件行为和依赖不变；仍使用固定编译器 0.10.17+d971670cd、async@0.19.3。此补丁不声称解决本机 MSVC D8050。
- [实际内容清单及验收报告](../packaging/candidate-0.1.1.json)，原始 SHA-256：`d5454b944e8a21a37f65eab8da495f96ba0eb97849a6c6458a057844162c41ac`。

## 具体归档与验收

[CI 42958886625](https://github.com/serikaonoe123/moonrdiff/actions/runs/42958886625) 的两份实际 ZIP 已下载并逐项核对 Git 提交和清单；两平台按路径比较的 34 件内容完全相同。条目顺序/ZIP 元数据可不同，授权绑定固定源码和文件内容清单。

| 产物 | ZIP 大小 | ZIP SHA-256 |
| --- | ---: | --- |
| package-candidate-ubuntu-24.04 | 50,409 字节 | `b7ebd19b15650a05c68f35bd6c45e6400dbb27f7f5e22ef989f31932b4a10e5c` |
| package-candidate-windows-latest | 50,409 字节 | `dfb9e2fb6e162bc70f5280bc52857921a9a4a0a1d8427db223d902897beda9f5` |

完整 CI 包括三后端核心测试、debug/release 原生 CLI、独立归档消费者三个后端各五组、提取归档内 CLI 流程、330 项 rdiff 互操作。另有 [两平台大文件验收 42958886507](https://github.com/serikaonoe123/moonrdiff/actions/runs/42958886507) 和 [固定 0.1.0 注册表回归 42958886562](https://github.com/serikaonoe123/moonrdiff/actions/runs/42958886562)，均通过。

本地审阅副本在 results/release-0.1.1/，包含实际 Linux ZIP 和原始候选报告。常规 CI 持续检查该报告的原始字节哈希。

## 授权后的执行

从固定提交建立隔离目录，核对全部内容哈希，正常安装并确认声明依赖为 async@0.19.3，然后用官方完整打包/解包/检查流程公开上传 0.1.1。0.1.0 的发布记录说明了 --frozen 会阻止新建临时校验目录安装依赖的问题，因此发布命令采用官方 `moon publish` 默认验证流程，并再次核对最终归档内容；不关闭校验。

成功后按批准的 0.1.1 清单执行独立注册表安装验收；工作流可手动选择 version=0.1.1，常规触发仍固定测试已经发布的 0.1.0。未上传 0.1.1 前不把该版本称为注册表已验收。若上传遇到安全/权限拒绝或版本已存在，保留证据并报告，不自行更换版本或权限。
