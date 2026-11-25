#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
export LC_ALL=C

cli=$(realpath -- "${1:?native MoonRdiff executable required}")
test -x "$cli"
mkdir -p results
report_dir=$(mktemp -d "$PWD/results/linux-publication-interruption-XXXXXXXX")
target_bytes=262144
basis="$report_dir/basis.bin"
delta="$report_dir/update.delta"
manifest="$report_dir/binding.json"
before="$report_dir/before.bin"
after="$report_dir/after.bin"

echo "Linux publication interruption evidence: $report_dir"
head -c "$target_bytes" /dev/zero | tr '\000' '\245' > "$basis"
"$cli" signature "$basis" "$report_dir/basis.sig" > "$report_dir/signature.json"
"$cli" delta "$report_dir/basis.sig" "$basis" "$delta" --basis-size "$target_bytes" > "$report_dir/delta.json"
"$cli" manifest "$basis" "$basis" "$delta" "$manifest" > "$report_dir/manifest.json"
sha256sum -- "$basis" "$delta" "$manifest" > "$report_dir/inputs.sha256"

interrupt_patch() {
  local syscall=$1 destination=$2 log=$3 status=0
  # Stop only this test process and prevent the interrupted operation from completing.
  strace -f -y -s 512 -e trace=fsync,renameat2,rmdir \
    "--inject=$syscall:error=EINTR:signal=SIGKILL" -o "$log.trace" \
    "$cli" patch "$basis" "$delta" "$destination" --manifest "$manifest" \
    > "$log.stdout" 2> "$log.stderr" || status=$?
  printf '%s\n' "$status" > "$log.exit"
  test "$status" -eq 137
  test ! -s "$log.stdout"
  grep -Fq '+++ killed by SIGKILL +++' "$log.trace"
}

interrupt_patch renameat2 "$before" "$report_dir/before"
test ! -e "$before"
test ! -L "$before"
stages=("$before".moonrdiff-stage-*)
test "${#stages[@]}" -eq 1
before_stage=${stages[0]}
cmp -- "$basis" "$before_stage/data"
grep -F "<$before_stage/data>" "$report_dir/before.trace" | grep -E '=[[:space:]]*0$'
grep -F 'renameat2(' "$report_dir/before.trace" | grep -F "\"$before\", RENAME_NOREPLACE"
"$cli" patch "$basis" "$delta" "$before" --manifest "$manifest" > "$report_dir/before-retry.json"
grep -F '"manifest_verified":true' "$report_dir/before-retry.json"
cmp -- "$basis" "$before"
cmp -- "$basis" "$before_stage/data"

interrupt_patch rmdir "$after" "$report_dir/after"
cmp -- "$basis" "$after"
stages=("$after".moonrdiff-stage-*)
test "${#stages[@]}" -eq 1
after_stage=${stages[0]}
test -d "$after_stage"
test -z "$(find "$after_stage" -mindepth 1 -print -quit)"
grep -F "\"$after\", RENAME_NOREPLACE" "$report_dir/after.trace" | grep -E '=[[:space:]]*0$'
grep -F "rmdir(\"$after_stage\")" "$report_dir/after.trace"
retry=0
"$cli" patch "$basis" "$delta" "$after" --manifest "$manifest" \
  > "$report_dir/after-retry.stdout" 2> "$report_dir/after-retry.stderr" || retry=$?
test "$retry" -eq 2
test ! -s "$report_dir/after-retry.stdout"
grep -F 'Output already exists' "$report_dir/after-retry.stderr"
cmp -- "$basis" "$after"
sha256sum --check "$report_dir/inputs.sha256"

printf 'result=passed\ncommit=%s\ntarget_bytes=%s\nbefore_retry=restored\nafter_retry=refused\n' \
  "$(git rev-parse HEAD)" "$target_bytes" | tee "$report_dir/summary.txt"
