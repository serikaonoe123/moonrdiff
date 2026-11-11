# MoonRdiff 0.1.1 文档补丁发布记录

`serikaonoe123/moonrdiff@0.1.1` 已于 2026-11-11 按用户明确批准的 [方案](RELEASE-PROPOSAL-0.1.1.md) 发布。固定提交为 `9ed7e11ea5f298a1ba3877a8932f54e8d8bd1200`，包内 34 件文件、源码合计 135,990 字节，只有 README 与版本号相对 0.1.0 的批准清单变化。API、算法、预算、依赖和文件语义均未改变。

README 已移除发布前的候选/尚未发布措辞。0.1.0 的原始已发布内容仍保留，相关文案遗漏由本维护版本修正。

## 上传与独立验收

从固定提交创建隔离发布目录，逐件核对 [批准清单](../packaging/candidate-0.1.1.json)，正常安装并确认 async@0.19.3，执行冻结打包审计后，用官方 moon publish 完整打包/解包/检查流程上传。服务端返回 200 OK，exit 0；最终 ZIP 再次匹配全部批准文件哈希。日志和预检查记录位于本地 results/release-0.1.1/。

随后明确选择 version=0.1.1，执行 [注册表安装验收 42959755305](https://github.com/serikaonoe123/moonrdiff/actions/runs/42959755305)。Windows/Linux 都要求来源为 registry、版本为 0.1.1；安装的 34 件源码均匹配批准清单，JS/Native/Wasm-GC 各五组公开消费者测试全部通过。下载报告和来源记录经官方成功日志核对，按原字节保存并由 CI 审计哈希：

| 平台 | 报告 | 来源 |
| --- | --- | --- |
| Linux | [report](../packaging/registry-0.1.1/linux-report.json) | [resolution](../packaging/registry-0.1.1/linux-resolution.json) |
| Windows | [report](../packaging/registry-0.1.1/windows-report.json) | [resolution](../packaging/registry-0.1.1/windows-resolution.json) |

此前完整 CI 42958886625、两平台大文件验收 42958886507、固定 0.1.0 注册表回归 42958886562 均通过。工作流常规触发仍验证已发布 0.1.0，手动输入可明确选择已有批准清单的版本，避免候选版本号影响旧版本回归。

## 本机 Native 状态

本次只读检查记录见 [NATIVE-WINDOWS-DIAGNOSTIC.md](NATIVE-WINDOWS-DIAGNOSTIC.md)。已观察到工作区完整性标签、沙箱托管临时目录、工具集版本及低 C: 可用空间；这些不构成 D8050 根因证明。没有运行新的本机 MSVC 编译、修改 ACL/完整性标签、切换沙箱、覆盖 TEMP/TMP 或改编译标志。云端 Native 安装验收通过不表示本机环境已修复。

此版本完成文案修正与发布验收。本机 D8050 仍待进一步采集失败进程上下文；真实应用集成与更多数据覆盖仍是后续维护工作。
