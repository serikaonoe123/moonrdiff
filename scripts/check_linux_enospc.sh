#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

cli=$(realpath -- "${1:?native MoonRdiff executable required}")
test -x "$cli"
mkdir -p results
report_dir=$(mktemp -d "$PWD/results/linux-enospc-XXXXXXXX")
limited=$(mktemp -d "${RUNNER_TEMP:-/tmp}/moonrdiff-enospc-XXXXXXXX")
capacity=1048576
target_bytes=2097152
basis="$report_dir/basis.bin"
delta="$report_dir/update.delta"
manifest="$report_dir/binding.json"
destination="$limited/restored.bin"

echo "ENOSPC evidence: $report_dir"
head -c "$target_bytes" /dev/zero > "$basis"
"$cli" signature "$basis" "$report_dir/basis.sig" > "$report_dir/signature.json"
"$cli" delta "$report_dir/basis.sig" "$basis" "$delta" --basis-size "$target_bytes" > "$report_dir/delta.json"
"$cli" manifest "$basis" "$basis" "$delta" "$manifest" > "$report_dir/manifest.json"
sha256sum -- "$basis" "$delta" "$manifest" > "$report_dir/inputs.sha256"

# Verify the same bound patch on the runner's normal filesystem before injecting ENOSPC.
"$cli" patch "$basis" "$delta" "$report_dir/control.bin" --manifest "$manifest" > "$report_dir/control.json"
cmp -- "$basis" "$report_dir/control.bin"

# Only this freshly created, private mount is capacity-limited.
sudo -n mount -t tmpfs -o "size=$capacity,mode=0700,uid=$(id -u),gid=$(id -g),nodev,nosuid,noexec" tmpfs "$limited"
trap 'sudo -n umount -- "$limited"' EXIT
test "$(findmnt --noheadings --output FSTYPE --mountpoint "$limited")" = tmpfs
read -r blocks block_bytes < <(stat --file-system --format='%b %S' -- "$limited")
test "$((blocks * block_bytes))" -eq "$capacity"
printf 'existing data\n' > "$limited/existing.txt"
cp -- "$limited/existing.txt" "$report_dir/existing.txt"

status=0
"$cli" patch "$basis" "$delta" "$destination" --manifest "$manifest" \
  > "$report_dir/enospc.stdout" 2> "$report_dir/enospc.stderr" || status=$?
test "$status" -eq 2
test ! -s "$report_dir/enospc.stdout"
test ! -e "$destination"
test ! -L "$destination"
grep -Ei 'ENOSPC|No space left on device' "$report_dir/enospc.stderr"
stage_dirs=("$destination".moonrdiff-stage-*)
test "${#stage_dirs[@]}" -eq 1
stage="${stage_dirs[0]}"
test -f "$stage/data"
grep -Fx "moonrdiff: Output was not published. Staging evidence: $stage" "$report_dir/enospc.stderr"
partial_bytes=$(stat --format=%s -- "$stage/data")
test "$partial_bytes" -gt 0
test "$partial_bytes" -lt "$target_bytes"
cmp -n "$partial_bytes" -- "$basis" "$stage/data"
cmp -- "$report_dir/existing.txt" "$limited/existing.txt"
sha256sum --check "$report_dir/inputs.sha256"

sudo -n umount -- "$limited"
trap - EXIT
rmdir -- "$limited"
printf 'result=passed\ncommit=%s\nfilesystem=tmpfs\ncapacity_bytes=%s\ntarget_bytes=%s\nexit_status=%s\npartial_bytes=%s\n' \
  "$(git rev-parse HEAD)" "$capacity" "$target_bytes" "$status" "$partial_bytes" | tee "$report_dir/summary.txt"
