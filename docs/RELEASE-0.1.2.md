# MoonRdiff 0.1.2 发布记录

`serikaonoe123/moonrdiff@0.1.2` 已于 2026-11-12 按用户明确批准的 [方案](RELEASE-PROPOSAL-0.1.2.md) 发布，固定源码为 `287872c13b6f2865b3657c10d66ce6eff88cff30`。包内 34 文件、源码合计 145,485 字节，保持公共库 API、格式、默认预算和依赖不变。

主要改进为原生 verify 成对读取至多 64 KiB，保留原四字段 JSON、退出码和选项；增加分块完整链路回归并更新说明。输入仍须稳定，不承诺文件快照、事务输出、发布者认证或通用进程内存上限。

## 上传与安装验收

从固定提交创建隔离发布目录，逐文件核对 [批准清单](../packaging/candidate-0.1.2.json)，确认 async@0.19.3。冻结打包审计通过后，官方 moon publish 完整打包/解包/检查及上传返回 exit 0、200 OK。最终 ZIP 为 52,740 字节，SHA-256 `0f064d76cdbf0ad11229a6cac2059a94c48fb4de1f135667aff5dee2b9d6b47e`，与已测 Windows 候选相同，发布前后内容均匹配清单。预检和原始日志保留于 results/release-0.1.2/。

明确选择 version=0.1.2 的 [注册表安装验收 43157315047](https://github.com/serikaonoe123/moonrdiff/actions/runs/43157315047) 在 Windows/Linux 均通过：来源为 registry、版本为 0.1.2、安装的 34 文件与批准哈希一致；三个后端各五组公开消费者测试通过。

| 平台 | 原始报告 | 来源记录 |
| --- | --- | --- |
| Linux | [report](../packaging/registry-0.1.2/linux-report.json) | [resolution](../packaging/registry-0.1.2/linux-resolution.json) |
| Windows | [report](../packaging/registry-0.1.2/windows-report.json) | [resolution](../packaging/registry-0.1.2/windows-resolution.json) |

原始字节已与官方成功日志核对并纳入 CI 哈希审计。候选此前已通过完整 CI 43156224761、128 MiB 验收 43156224769 和旧版本 0.1.1 回归 43156256428；详见方案及 VALIDATION.md。

安装依赖为 `serikaonoe123/moonrdiff@0.1.2`，最小消费者见完整仓库 examples/consumer。0.1.0/0.1.1 内容未修改。本次没有创建 GitHub Release 或标签。历史 D8050 当前未再复现，本版不声称已定位其根因。
