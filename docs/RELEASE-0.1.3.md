# MoonRdiff 0.1.3 发布记录

`serikaonoe123/moonrdiff@0.1.3` 已于 2026-11-18 按用户明确批准的 [方案](RELEASE-PROPOSAL-0.1.3.md) 发布，固定源码为 `79a958d6e55a634daf4f680b999bdfc78d5f9320`。包内 34 文件、源码合计 150,757 字节，公共库 API、rdiff 格式、默认预算和 async@0.19.3 依赖保持不变。

主要改进是原生 signature/delta/patch/manifest 在目标旁暂存、同步并关闭后禁止替换发布，清理空目录后才输出成功 JSON。失败保留暂存证据；发布后收尾失败返回 2 并明确标识最终路径，调用方需先检查再决定后续处理。输入和父目录仍须稳定可信，实际磁盘满、同步失败、断电及全部文件系统的原子性/目录持久性尚未验证。

## 上传与安装验收

从固定提交创建隔离发布目录，核对 [批准清单](../packaging/candidate-0.1.3.json)、全部 Git 原文及 async@0.19.3 依赖。官方 moon publish 完整打包、解包、检查及上传返回 exit 0、200 OK。发布前后 ZIP 均为 54,891 字节，SHA-256 `5b6d070c2ccecb995b4a3c40aefafeb49509740b72ae426c81743f4accc09fa4`，与已测 Windows 候选完全相同；每个文件仍匹配批准清单。预检、单次发布意图和原始日志保留于 results/release-0.1.3/。

明确选择 version=0.1.3 的 [注册表安装验收 44272240210](https://github.com/serikaonoe123/moonrdiff/actions/runs/44272240210) 在 Windows/Linux 均通过：来源为 registry、版本为 0.1.3，下载的全部 34 个批准文件哈希一致；JS、Native、Wasm-GC 各五组公开消费者测试通过。独立核对官方两条成功日志、原始报告/来源记录、批准提交与 async 版本后归档：

| 平台 | 原始报告 | 来源记录 |
| --- | --- | --- |
| Linux | [report](../packaging/registry-0.1.3/linux-report.json) | [resolution](../packaging/registry-0.1.3/linux-resolution.json) |
| Windows | [report](../packaging/registry-0.1.3/windows-report.json) | [resolution](../packaging/registry-0.1.3/windows-resolution.json) |

原始字节纳入 CI 固定哈希校验，候选报告及历史发布记录保持原样。发布前的完整 CI 44267566097、128 MiB 验收 44267566157 和旧版 0.1.2 回归 44267638263 均通过，详见批准方案。

安装依赖为 `serikaonoe123/moonrdiff@0.1.3`，最小消费者见完整仓库 examples/consumer。注册表工作流默认改为 0.1.3；资源缓存应用继续固定使用 0.1.2，保留其原始可复现基准。本次没有创建 GitHub Release 或标签。历史 D8050 根因仍未确认。
