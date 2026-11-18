# 独立资源缓存应用

`examples/resource-cache/` 是单独的 MoonBit 模块，导入公开发布的 `serikaonoe123/moonrdiff@0.1.2`，只使用根包公开接口，不引用本仓库源码或内部 BLAKE2 实现。更新流程、传输选择和校验由 MoonBit 编写；Node.js 内置文件接口与 `crypto` 提供本地读写和 SHA-256。

本例更新的是 MoonFFI Lab 的源码包缓存。它使用真实的跨项目数据，仍属于同一作者的集成示例，不代表第三方采用、网络服务或生产部署。

## 固定数据与复现

环境：MoonBit `0.10.17+d971670cd`、Node.js 22、支持 `archive --mtime` 的 Git。CI 在 Windows/Linux 使用同一固定工具链；本地报告记录实际版本。

数据来源为公开 MIT 项目 [MoonFFI Lab](https://github.com/serikaonoe123/moonffi-lab)：

| 版本 | 固定提交 |
| --- | --- |
| v0.1.0-rc.1 | `23893d5bb3a231a21df10db506d8da821a7e984d` |
| v0.1.0-rc.2 | `20b608d6d8546873d5d66786dc8e12642dd70e9c` |

只从这两个 Git 提交归档 `LICENSE`、`moon.mod`、`core/`，不读取工作区改动。TAR 时间固定为零，归档命令单次指定 `core.autocrlf=false`、`core.eol=lf`，避免平台换行转换；不修改 Git 配置。每份归档保留原始 MIT 许可证。报告列出每个源文件的字节数及 SHA-256、归档摘要、Git 版本和依赖解析来源。生成的源码包留在 `results/`，不随 Mooncakes 包分发。

```sh
git clone https://github.com/serikaonoe123/moonffi-lab.git ../moonffi-lab
cd examples/resource-cache
moon update
cd ../..
node scripts/check_resource_cache.mjs ../moonffi-lab
```

已有包含这两个提交的克隆可直接传入路径。脚本要求依赖来自注册表，拒绝用本地工作区代替。它运行独立模块的格式、检查及真实文件流程；报告保存在 `results/resource-cache-*/report.json`，失败保留日志和现有数据，不自动重试、删除或修改权限。

## 三步应用流程

以下命令从 `examples/resource-cache/` 执行，路径由调用者提供。每次生成的文件必须尚不存在；`build` 的输出目录必须已存在。

```sh
moon run . --target js --release -- offer OLD_CACHE OFFER_JSON
moon run . --target js --release -- build OFFER_JSON TARGET_FILE OUTPUT_DIRECTORY
moon run . --target js --release -- apply OLD_CACHE MANIFEST_JSON PAYLOAD_BIN TRUSTED_TARGET_SHA256 NEW_CACHE
```

1. 缓存端生成 `offer`，包含旧文件 SHA-256、大小及十六进制编码的 RK/BLAKE2 摘要；块大小为 1024 字节。
2. 发布端仅接收 offer 和新文件，无旧文件参数。它产生差量及两种清单，计入 offer、清单和内容的实际字节数，差量首次交换总量小于直接完整下载时选择差量，否则发送完整内容。验收将发布端输入单独放置并检查目录不含旧文件；这是数据流分离，不是操作系统访问隔离。
3. 接收端要求调用者另外提供可信目标 SHA-256，核对清单、内容摘要、旧文件摘要（差量模式）及最终大小/摘要后，以独占创建方式写入新的缓存版本。完整模式不需要读取旧缓存。原缓存保留，示例不切换应用的活动版本指针。

可信目标摘要应来自调用者已经信任的发布目录或配置，不能直接照抄待验收清单。SHA-256 检测内容/版本不符，不认证发布者；本例不实现签名、密钥管理、HTTP 或重试协议。示例的 SHA-256 清单不是原生 CLI 的 BLAKE2 绑定格式。

## 成本与验证范围

`first_delta_bytes = offer_bytes + delta_bytes + delta_manifest_bytes`；`direct_full_bytes = target_bytes + full_manifest_bytes`。offer 已发送后才决定交付方式，因此 `actual_exchange_bytes` 即使回退完整下载，也保留已发送的 offer 成本；`selected_remaining_bytes` 单列后续发送量。JSON 中十六进制摘要的开销按实际文件计入。没有省略清单或把已发送的摘要当成免费。

本地固定换行后的结果：新 TAR 102400 字节；历史更新的 offer/差量/清单分别为 4477/57604/302 字节，合计 62383 字节，直接完整下载含清单为 102701 字节。空缓存回退完整下载，实际交换 102854 字节（其中 offer 153 字节）；这比一开始直接下载更贵。这里只是一个真实源码包样本，不是通用节省比例、时间或内存性能结论。云端结果单独记录在 VALIDATION.md。

验收覆盖历史版本差量更新、空缓存完整下载，两者均逐字节还原并保留旧缓存。17 项拒绝检查覆盖错误可信摘要、损坏内容、错误目标大小/摘要、未知清单版本/交付类型、超预算、差量旧缓存错误、已有目标不覆盖；每次失败使用独立输出路径并要求不产生成功 JSON。

## 边界

这是小文件内存接口示例：旧/新文件最多 8 MiB，offer 最多 1 MiB，清单最多 4096 字节，交付内容最多 16 MiB，摘要最多 8192 块。十六进制、JSON 和候选计算会增加内存，没有常量内存承诺。文件路径和并发由调用者控制。

独占创建避免覆盖已有文件，但本例没有原生 CLI 的分阶段发布流程；真实写入失败可能保留部分新文件，不提供断电持久性、并发切换、实际磁盘写满或同步失败验证。不要将它当成已经部署的缓存更新服务。库、原生 CLI 和已发布包保持原样；本例只存在于完整仓库中。
