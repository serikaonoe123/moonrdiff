# MoonRdiff 0.1.3 文字验收指南

这份指南依次验收 Mooncakes 安装、原生命令的带清单还原，以及真实源码包的差量更新。请从一个新的空目录开始。命令使用 Bash，Windows 可用 Git Bash，并在 PowerShell 中运行原生构建。Windows 和 Linux 都需要 Git、MoonBit `0.10.17+d971670cd` 和 Node.js。CI 使用 Node.js 22。原生步骤需要 MoonBit Native 能找到的 C 编译器。最后一步需要支持 `git archive --mtime` 的 Git。

## 1. 从 Mooncakes 安装并运行库示例

创建最小消费者。`moon.pkg` 将根包导入为 `@rdiff`，测试生成旧文件摘要和补丁，再对还原字节做断言。

```bash
mkdir registry-consumer
cd registry-consumer
cat > moon.mod <<'EOF'
name = "moonrdiff-review/consumer"
version = "0.0.1"
preferred_target = "js"
import {
  "serikaonoe123/moonrdiff@0.1.3",
}
EOF
cat > moon.pkg <<'EOF'
import {
  "serikaonoe123/moonrdiff" @rdiff,
} for "test"
EOF
cat > roundtrip_test.mbt <<'EOF'
///|
test "restore target using the published package" {
  let basis = b"abcdefghijk"
  let target = b"!ijkabcdefgh!"
  let signature = @rdiff.parse_signature(@rdiff.signature(basis, block_size=4))
  let delta = @rdiff.delta(signature, target, basis_size=basis.length())
  let result = @rdiff.patch(basis, delta, max_output=target.length())
  assert_eq(result, target)
}
EOF
moon update
moon tree --json
moon test --target js --deny-warn
cd ..
```

在依赖解析结果中检查 `serikaonoe123/moonrdiff` 的 `version` 为 `0.1.3`，`source.kind` 为 `registry`。测试应显示 `Total tests: 1, passed: 1, failed: 0.`。正式验收另核对了下载包的 34 个文件，并在每个平台的三个后端各执行五组消费者测试。[发布记录与原始安装证据](RELEASE-0.1.3.md)

## 2. 用原生命令还原文件并检查失败结果

从验收目录克隆仓库并检出 `92507c0`。该提交包含下文的 TAR、gzip 和 Lua 验收脚本。核心库、原生 CLI 和依赖版本与 Mooncakes 0.1.3 发布提交一致。[固定验收源码](https://github.com/serikaonoe123/moonrdiff/tree/92507c0afffa5e342fe10a323ce04d747b887f75)

```bash
git clone https://github.com/serikaonoe123/moonrdiff.git
cd moonrdiff
git checkout --detach 92507c0afffa5e342fe10a323ce04d747b887f75
moon update
```

在仓库根目录构建 CLI。Linux 可继续用当前终端，Windows 用常规 PowerShell 打开同一个仓库目录。跟踪测试中，两种终端在同一个诊断执行环境都出现过 D8050，常规 PowerShell 的全新构建通过。[Windows 编译记录](NATIVE-WINDOWS-DIAGNOSTIC.md)

```text
moon build cmd/moonrdiff --target native --release --deny-warn
```

构建成功后回到 Bash 中的仓库目录。`printf` 生成无换行的文件，旧文件恰好 11 字节。

```bash
mkdir walkthrough-data
printf '%s' 'abcdefghijk' > walkthrough-data/old.bin
printf '%s' '!ijkabcdefgh!' > walkthrough-data/new.bin
cli=./_build/native/release/build/cmd/moonrdiff/moonrdiff.exe
"$cli" signature walkthrough-data/old.bin walkthrough-data/old.sig --block-size 4
"$cli" delta walkthrough-data/old.sig walkthrough-data/new.bin walkthrough-data/update.delta --basis-size 11
"$cli" manifest walkthrough-data/old.bin walkthrough-data/new.bin walkthrough-data/update.delta walkthrough-data/binding.json
"$cli" patch walkthrough-data/old.bin walkthrough-data/update.delta walkthrough-data/restored.bin --manifest walkthrough-data/binding.json
"$cli" verify walkthrough-data/new.bin walkthrough-data/restored.bin
cmp walkthrough-data/new.bin walkthrough-data/restored.bin
if "$cli" verify walkthrough-data/new.bin walkthrough-data/old.bin; then
  false
else
  test "$?" -eq 1
fi
```

`signature` 应报告 `basis_size: 11`，带清单的 `patch` 应报告 `manifest_verified: true`。首次 `verify` 应返回 `matched: true`，两个长度都为 13。`cmp` 成功时没有输出。最后一次 `verify` 应报告 `matched: false`，退出码为 1。再次生成文件请使用新的输出路径。命令返回 2 时按错误提示判断最终文件是否已写入，以及暂存数据的位置。[文件命令和暂存规则](CLI.md#文件行为)

## 3. 验收真实资源缓存

从上一步的 `moonrdiff` 仓库目录执行。参考仓库的完整历史提供两份固定的 MoonFFI Lab 源码归档，验收脚本从 Mooncakes 解析 0.1.3，并先检查 34 个安装文件的哈希。

```bash
git clone https://github.com/serikaonoe123/moonffi-lab.git ../moonffi-lab
node scripts/check_resource_cache.mjs ../moonffi-lab
```

已有 MoonFFI Lab 克隆时，可跳过 `git clone`，将最后一个参数替换为该克隆的路径。脚本会验证两个固定提交和归档内容。

终端应显示 `Resource cache accepted: 3 real-data cases, 25 rejection controls.`，并给出 `results/resource-cache-*/report.json` 的路径。报告的 `passed` 为 true，`registry_inventory.files_verified` 为 34。前两项还原同一份 TAR，第三项还原本次运行生成的 gzip 压缩文件。下表的字节数在 Windows 和 Linux 上实测一致。gzip 文件的字节数和摘要以各次运行的报告为准。[输入来源与复现细节](RESOURCE-CACHE.md)

| 情景 | 交付方式 | 含清单和已发送摘要的总字节数 |
| --- | --- | ---: |
| 已有旧源码包 | 差量 | 52,031 |
| 空缓存 | 完整文件 | 102,854 |
| 已有旧的 gzip 源码包 | 完整文件 | 21,710 |

TAR 直接完整下载含清单为 102,701 字节，历史更新节省约 49.3%。空缓存流程多计 153 字节的已发送请求。gzip 样本直接完整下载含清单为 20,689 字节，实际交换额外计入 1,021 字节的已发送请求。[三个场景的两平台报告](https://github.com/serikaonoe123/moonrdiff/actions/runs/44686979238)

需要验证独立项目的数据时，可选做 Lua 官方发布包验收。在同一个仓库目录执行，需安装 `curl`。

```bash
mkdir -p results/lua-release-inputs
curl -fS https://www.lua.org/ftp/lua-5.4.7.tar.gz -o results/lua-release-inputs/lua-5.4.7.tar.gz
curl -fS https://www.lua.org/ftp/lua-5.4.8.tar.gz -o results/lua-release-inputs/lua-5.4.8.tar.gz
node scripts/check_resource_cache.mjs ../moonffi-lab results/lua-release-inputs
```

脚本核对官网公布的 SHA-256，并分别还原原始 gzip 和解压后的 TAR。终端应显示 `Resource cache accepted: 5 real-data cases, 42 rejection controls.`。[Lua 样本数据与两平台验收](RESOURCE-CACHE.md#独立项目样本)

## 兼容性与证据

| 验收项 | 通过的平台或后端 | 验证范围 | 记录 |
| --- | --- | --- | --- |
| Mooncakes 安装与库 API | Windows、Linux，均覆盖 JS / Native / Wasm-GC | 0.1.3 的 34 文件哈希和每后端五组公开 API 测试 | [注册表 CI](https://github.com/serikaonoe123/moonrdiff/actions/runs/44272240210) |
| 原生 CLI | Windows、Linux，debug / release | 摘要、差量、绑定还原、逐字节校验与拒绝覆盖 | [固定发布提交的完整 CI](https://github.com/serikaonoe123/moonrdiff/actions/runs/44267566097) |
| 原生 CLI 大文件 | Windows、Linux，release | 五类 128 MiB 级样本，修改样本的绑定还原，默认预算拒绝 | [128 MiB 验收](https://github.com/serikaonoe123/moonrdiff/actions/runs/44267566157) |
| rdiff 2.3.4 互操作 | Linux | RK/BLAKE2 摘要和 rdiff 补丁，双实现交叉生成与还原，共 330 项 | [固定发布提交的完整 CI](https://github.com/serikaonoe123/moonrdiff/actions/runs/44267566097) |
| 真实资源缓存 | Windows、Linux，JS / Node.js 22 | 0.1.3、TAR 历史更新、空缓存和 gzip 更新，每平台 25 项拒绝检查 | [资源缓存 CI](https://github.com/serikaonoe123/moonrdiff/actions/runs/44686979238) |

JS 与 Wasm-GC 的验收范围是库 API。原生文件命令使用 Native。`rdiff` 互操作覆盖 RK/BLAKE2 摘要与标准补丁指令。Linux tmpfs 和 Windows 虚拟磁盘上的 NTFS 均已验证原生 `patch` 写满时的退出码、诊断和暂存行为。Linux 测试向 `fsync` 注入 `EIO`，Windows 测试构建用无效句柄触发 `FlushFileBuffers` 错误。两项同步失败测试均核对完整暂存内容和最终路径。物理设备故障与断电恢复仍待验证。[Linux 同步失败验收](LARGE-FILES.md#linux-file-sync-failure) · [Windows 同步失败验收](LARGE-FILES.md#windows-file-sync-failure)

Linux CI 还覆盖发布前后两种进程突然退出的情况。发布前中断保留完整暂存文件，重试可完成还原。发布后中断保留最终文件，重试拒绝覆盖。[Linux 进程中断验收](LARGE-FILES.md#linux-process-interruption-at-publication)
