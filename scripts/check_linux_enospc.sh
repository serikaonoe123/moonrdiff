#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

cli=$(realpath -- "${1:?native MoonRdiff executable required}")
test -x "$cli"
filesystem=${2:-tmpfs}
case "$filesystem" in
  tmpfs) capacity=1048576; target_bytes=2097152 ;;
  ext4)
    test "${GITHUB_ACTIONS:-}" = true
    test "${RUNNER_ENVIRONMENT:-}" = github-hosted
    capacity=16777216
    target_bytes=25165824
    ;;
  *) echo "Unsupported capacity test filesystem: $filesystem" >&2; exit 2 ;;
esac

mkdir -p results
report_dir=$(mktemp -d "$PWD/results/linux-enospc-$filesystem-XXXXXXXX")
scratch=$(mktemp -d "${RUNNER_TEMP:-/tmp}/moonrdiff-enospc-XXXXXXXX")
limited="$scratch/mount"
mkdir -- "$limited"
image=''
mounted=false

cleanup() {
  if [[ "$mounted" == true ]]; then
    sudo -n umount -- "$limited" || return
    mounted=false
  fi
  if [[ -n "$image" ]]; then rm -f -- "$image" || return; fi
  rmdir -- "$limited" "$scratch"
}
trap cleanup EXIT

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

# Format only a newly created regular file under the private scratch directory.
if [[ "$filesystem" == ext4 ]]; then
  image=$(mktemp -- "$scratch/volume-XXXXXXXX")
  test -f "$image"
  test ! -L "$image"
  fallocate --length "$capacity" -- "$image"
  mkfs.ext4 -q -F -m 0 -E nodiscard "$image"
  sudo -n mount -t ext4 -o loop,nodev,nosuid,noexec "$image" "$limited"
else
  sudo -n mount -t tmpfs -o "size=$capacity,mode=0700,uid=$(id -u),gid=$(id -g),nodev,nosuid,noexec" tmpfs "$limited"
fi
mounted=true
test "$(findmnt --noheadings --output FSTYPE --mountpoint "$limited")" = "$filesystem"
if [[ "$filesystem" == ext4 ]]; then
  device=$(findmnt --noheadings --output SOURCE --mountpoint "$limited")
  test "$(sudo -n losetup --noheadings --raw --output BACK-FILE "$device")" = "$image"
  sudo -n chown "$(id -u):$(id -g)" -- "$limited"
fi
read -r blocks block_bytes < <(stat --file-system --format='%b %S' -- "$limited")
filesystem_bytes=$((blocks * block_bytes))
if [[ "$filesystem" == tmpfs ]]; then
  test "$filesystem_bytes" -eq "$capacity"
else
  test "$filesystem_bytes" -gt 1048576
  test "$filesystem_bytes" -le "$capacity"
fi
printf 'existing data\n' > "$limited/existing.txt"
cp -- "$limited/existing.txt" "$report_dir/existing.txt"

status=0
"$cli" patch "$basis" "$delta" "$destination" --manifest "$manifest" \
  > "$report_dir/enospc.stdout" 2> "$report_dir/enospc.stderr" || status=$?
test "$status" -eq 2
test ! -s "$report_dir/enospc.stdout"
test ! -e "$destination"
test ! -L "$destination"
grep -F '@fs.File::write(): No space left on device' "$report_dir/enospc.stderr"
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

cleanup
trap - EXIT
printf 'result=passed\ncommit=%s\nfilesystem=%s\ncapacity_bytes=%s\ncapacity_limit_bytes=%s\ntarget_bytes=%s\nexit_status=%s\npartial_bytes=%s\n' \
  "$(git rev-parse HEAD)" "$filesystem" "$filesystem_bytes" "$capacity" "$target_bytes" "$status" "$partial_bytes" | tee "$report_dir/summary.txt"
