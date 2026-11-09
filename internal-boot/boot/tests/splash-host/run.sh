#!/bin/sh
# Host-only synthetic test runner. Does not invoke any repository build scripts.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
if [ -e "$root/internal-boot/boot/build/headless/splash-contract.h" ]; then
  echo 'Refusing to shadow an existing production splash contract; use a clean worktree.' >&2
  exit 1
fi
build=$(mktemp -d "${TMPDIR:-/tmp}/splash-host.XXXXXXXX")
trap 'rm -rf "$build"' EXIT HUP INT TERM
mkdir -p "$build/build/headless"
cp "$here/synthetic-contract.h" "$build/build/headless/splash-contract.h"
set -- -std=c11 -O1 -g -Wall -Wextra -Werror -fshort-wchar -DGU_SPLASH_HOST_TEST \
  -I "$build" -I "$root/deps/edk2/MdePkg/Include" -I "$root/deps/edk2/MdePkg/Include/X64"
# Guard is tested with syntax-only compilation, never an EFI build.
if gcc "$@" -ffreestanding -fsyntax-only "$here/test.c" >"$build/refusal.log" 2>&1; then
  echo 'FAIL: freestanding compilation was not refused' >&2; exit 1
fi
grep -q 'Splash harness requires a hosted build' "$build/refusal.log"
echo 'PASS: freestanding compilation refused'
gcc "$@" "$here/test.c" -o "$build/test"
timeout 60 "$build/test"
if [ "${SANITIZE:-0}" = 1 ]; then
  gcc "$@" -fsanitize=address,undefined -fno-omit-frame-pointer "$here/test.c" -o "$build/test-sanitize"
  ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 timeout 60 "$build/test-sanitize"
fi
