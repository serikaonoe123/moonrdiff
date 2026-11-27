#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
export LC_ALL=C

test "${GITHUB_ACTIONS:-}" = true
test "${RUNNER_ENVIRONMENT:-}" = github-hosted
cli=$(realpath -- "${1:?native MoonRdiff executable required}")
test -x "$cli"
mkdir -p results
report=$(mktemp -d "$PWD/results/linux-block-read-error-XXXXXXXX")
scratch=$(mktemp -d "${RUNNER_TEMP:-/tmp}/moonrdiff-block-XXXXXXXX")
mount_dir="$scratch/mount"
image="$scratch/volume.img"
mapping="${scratch##*/}"
mkdir -- "$mount_dir"
loop=''
mapped=false
mounted=false

cleanup() {
  if [[ "$mounted" == true ]]; then sudo -n umount -- "$mount_dir" || return; mounted=false; fi
  if [[ "$mapped" == true ]]; then sudo -n dmsetup remove "$mapping" || return; mapped=false; fi
  if [[ -n "$loop" ]]; then sudo -n losetup --detach "$loop" || return; loop=''; fi
  rm -f -- "$image"
  rmdir -- "$mount_dir" "$scratch"
}
trap cleanup EXIT

echo "Linux block read error evidence: $report"
block_size=4096
bad_file_block=8
target_bytes=262144
basis="$report/basis.bin"
delta="$report/update.delta"
manifest="$report/binding.json"
head -c "$target_bytes" /dev/urandom > "$basis"
printf 'unaffected file\n' > "$report/sentinel.txt"
"$cli" signature "$basis" "$report/basis.sig" --block-size "$block_size" > "$report/signature.json"
"$cli" delta "$report/basis.sig" "$basis" "$delta" --basis-size "$target_bytes" > "$report/delta.json"
test "$(stat -c %s -- "$delta")" -lt "$block_size"
"$cli" manifest "$basis" "$basis" "$delta" "$manifest" > "$report/manifest.json"
sha256sum -- "$basis" "$delta" "$manifest" > "$report/inputs.sha256"

# Construct the fixture on a new regular file before attaching anything.
touch -- "$image"
test -f "$image"
test ! -L "$image"
fallocate --length 32M -- "$image"
mkfs.ext4 -q -F -b "$block_size" -E nodiscard "$image"
debugfs -w -R "write \"$basis\" /basis.bin" "$image" > "$report/fixture.log" 2>&1
debugfs -w -R "write \"$report/sentinel.txt\" /sentinel.txt" "$image" >> "$report/fixture.log" 2>&1
image_block=$(debugfs -R "bmap /basis.bin $bad_file_block" "$image" 2>> "$report/fixture.log")
[[ "$image_block" =~ ^[1-9][0-9]*$ ]]
sha256sum -- "$image" > "$report/image.sha256"

# Attach only the test image, read-only, and fail one ext4 data block in its map.
loop=$(sudo -n losetup --find --show --read-only "$image")
test "$(sudo -n losetup --noheadings --raw --output BACK-FILE "$loop")" = "$image"
test "$(sudo -n blockdev --getro "$loop")" -eq 1
sectors=$(sudo -n blockdev --getsz "$loop")
block_sectors=$((block_size / 512))
bad_sector=$((image_block * block_sectors))
next_sector=$((bad_sector + block_sectors))
test "$next_sector" -lt "$sectors"
printf '0 %s linear %s 0\n%s %s error\n%s %s linear %s %s\n' \
  "$bad_sector" "$loop" "$bad_sector" "$block_sectors" \
  "$next_sector" "$((sectors - next_sector))" "$loop" "$next_sector" > "$report/table.txt"

# A healthy mount of the same image establishes that its input bytes are valid.
sudo -n mount -t ext4 -o ro,noload,nodev,nosuid,noexec "$loop" "$mount_dir"
mounted=true
cmp -- "$basis" "$mount_dir/basis.bin"
"$cli" patch "$mount_dir/basis.bin" "$delta" "$report/control.bin" --manifest "$manifest" > "$report/control.json"
cmp -- "$basis" "$report/control.bin"
sudo -n umount -- "$mount_dir"
mounted=false

sudo -n dmsetup create "$mapping" --readonly --table "$(cat "$report/table.txt")"
mapped=true
device="/dev/mapper/$mapping"
test "$(sudo -n blockdev --getro "$device")" -eq 1
sudo -n mount -t ext4 -o ro,noload,nodev,nosuid,noexec "$device" "$mount_dir"
mounted=true
cmp -- "$report/sentinel.txt" "$mount_dir/sentinel.txt"
bad_basis="$mount_dir/basis.bin"
if dd if="$bad_basis" of=/dev/null iflag=direct bs="$block_size" skip="$bad_file_block" count=1 status=none 2> "$report/probe.stderr"; then
  echo 'The targeted read unexpectedly succeeded.' >&2
  exit 1
fi
grep -F 'Input/output error' "$report/probe.stderr"

reject_patch() {
  local label=$1 status=0
  shift
  local destination="$report/$label.bin"
  "$cli" patch "$bad_basis" "$delta" "$destination" --chunk-size "$block_size" "$@" \
    > "$report/$label.stdout" 2> "$report/$label.stderr" || status=$?
  test "$status" -eq 2
  test ! -s "$report/$label.stdout"
  test ! -e "$destination"
  test ! -L "$destination"
  grep -F 'Input/output error' "$report/$label.stderr"
  local -a stages=("$destination".moonrdiff-stage-*)
  test "${#stages[@]}" -eq 1
  grep -Fx "moonrdiff: Output was not published. Staging evidence: ${stages[0]}" "$report/$label.stderr"
  stage="${stages[0]}"
}

reject_patch bound --manifest "$manifest"
test -z "$(find "$stage" -mindepth 1 -print -quit)"
reject_patch unbound
partial_bytes=$(stat -c %s -- "$stage/data")
test "$partial_bytes" -eq "$((bad_file_block * block_size))"
cmp -n "$partial_bytes" -- "$basis" "$stage/data"
cmp -- "$report/sentinel.txt" "$mount_dir/sentinel.txt"
sha256sum --check "$report/inputs.sha256"
sha256sum --check "$report/image.sha256"
cleanup
trap - EXIT
printf 'result=passed\ncommit=%s\nfilesystem=ext4\nerror=EIO\nbad_file_block=%s\nblock_bytes=%s\nbound_exit=2\nunbound_exit=2\nunbound_staged_bytes=%s\n' \
  "$(git rev-parse HEAD)" "$bad_file_block" "$block_size" "$partial_bytes" | tee "$report/summary.txt"
