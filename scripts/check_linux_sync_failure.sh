#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

cli=$(realpath -- "${1:?native MoonRdiff executable required}")
test -x "$cli"
mkdir -p results
report_dir=$(mktemp -d "$PWD/results/linux-sync-failure-XXXXXXXX")
target_bytes=262144
basis="$report_dir/basis.bin"
delta="$report_dir/update.delta"
manifest="$report_dir/binding.json"
control="$report_dir/control.bin"
destination="$report_dir/restored.bin"
tracer=(strace -qq -f -y -e trace=fsync)

echo "Linux sync-failure evidence: $report_dir"
strace --version > "$report_dir/strace-version.txt"
head -c "$target_bytes" /dev/zero | tr '\000' '\245' > "$basis"
"$cli" signature "$basis" "$report_dir/basis.sig" > "$report_dir/signature.json"
"$cli" delta "$report_dir/basis.sig" "$basis" "$delta" --basis-size "$target_bytes" > "$report_dir/delta.json"
"$cli" manifest "$basis" "$basis" "$delta" "$manifest" > "$report_dir/manifest.json"
sha256sum -- "$basis" "$delta" "$manifest" > "$report_dir/inputs.sha256"

# Establish that the same binary and patch normally sync and publish the result.
"${tracer[@]}" -o "$report_dir/control.trace" \
  "$cli" patch "$basis" "$delta" "$control" --manifest "$manifest" > "$report_dir/control.json"
cmp -- "$basis" "$control"
grep -F '"manifest_verified":true' "$report_dir/control.json"
grep -F "<$control.moonrdiff-stage-" "$report_dir/control.trace" | grep -E '/data>\).*=[[:space:]]*0$'

# strace launches this one CLI process and follows its I/O worker threads.
status=0
"${tracer[@]}" --inject=fsync:error=EIO -o "$report_dir/sync-failure.trace" \
  "$cli" patch "$basis" "$delta" "$destination" --manifest "$manifest" \
  > "$report_dir/sync-failure.stdout" 2> "$report_dir/sync-failure.stderr" || status=$?
test "$status" -eq 2
test ! -s "$report_dir/sync-failure.stdout"
test ! -e "$destination"
test ! -L "$destination"
grep -F '@fs.File::sync(): Input/output error' "$report_dir/sync-failure.stderr"
stage_dirs=("$destination".moonrdiff-stage-*)
test "${#stage_dirs[@]}" -eq 1
stage="${stage_dirs[0]}"
test -f "$stage/data"
grep -Fx "moonrdiff: Output was not published. Staging evidence: $stage" "$report_dir/sync-failure.stderr"
test "$(grep -cF '(INJECTED)' "$report_dir/sync-failure.trace")" -eq 1
grep -F "<$stage/data>" "$report_dir/sync-failure.trace" | grep -E '=[[:space:]]*-1 EIO .*\(INJECTED\)$'
cmp -- "$basis" "$stage/data"
sha256sum --check "$report_dir/inputs.sha256"

printf 'result=passed\ncommit=%s\ninjected_syscall=fsync\ninjected_error=EIO\nexit_status=%s\nstaged_bytes=%s\n' \
  "$(git rev-parse HEAD)" "$status" "$(stat --format=%s -- "$stage/data")" | tee "$report_dir/summary.txt"
