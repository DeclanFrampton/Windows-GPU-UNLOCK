#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Builds host executables only. Never invokes the EFI build or engine entrypoint.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=$(mktemp -d "${TMPDIR:-/tmp}/gpu-ownership-test.XXXXXXXX")
trap 'rm -rf "$out"' EXIT
cc=${CC:-cc}
flags=(-std=c11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter
  -fshort-wchar -D__KERNEL__ -DGU_UEFI_PORT -DGU_AD104_TRANSACTION
  -DGU_ENTRY_LATCHED_SS1_FULL -ffunction-sections -fdata-sections
  -Iexperimental -Iexperimental/include -Iexperimental/compat
  -Iexperimental/vendor/edk2/Include -Iexperimental/vendor/edk2/Include/X64)
source=experimental/tests/test_ownership.c
# This test fixture must never compile as a freestanding/firmware component.
if "$cc" "${flags[@]}" -ffreestanding -fsyntax-only "$source" > "$out/freestanding.txt" 2>&1; then
  echo 'Freestanding harness unexpectedly compiled' >&2
  exit 1
fi
if ! grep -Fq 'Ownership predicate harness requires hosted compilation' "$out/freestanding.txt"; then
  cat "$out/freestanding.txt" >&2
  echo 'Freestanding refusal did not report the intended diagnostic' >&2
  exit 1
fi
printf '%s\n' 'PASS: freestanding compilation refused with intended diagnostic.'
check_symbols() {
  # Fail if the engine entrypoint or any GPU/transaction implementation survives.
  if nm "$1" | grep -Eq ' (ExecuteGpuRamUnlock|Gu[A-Za-z0-9_]*|gpu_unlock_[A-Za-z0-9_]*|RestoreGpuPciDecode)$'; then
    echo 'Unexpected engine/hardware symbol in hosted test' >&2
    exit 1
  fi
}
"$cc" "${flags[@]}" "$source" -Wl,--gc-sections -o "$out/fixed"
check_symbols "$out/fixed"
"$out/fixed"
# Regression oracle: identical tests compile against the exact reviewed source.
base=a5b3535a538c7e8f76e849a3f84c3864c94fddcf
git show "$base:experimental/src/unlock_engine.c" > "$out/baseline.c"
"$cc" "${flags[@]}" -DOWNERSHIP_SOURCE="\"$out/baseline.c\"" "$source" -Wl,--gc-sections -o "$out/baseline"
check_symbols "$out/baseline"
"$out/baseline" --baseline
if "$out/baseline" > "$out/baseline-failure.txt" 2>&1; then
  echo 'Baseline unexpectedly passed corrected regression expectations' >&2
  exit 1
fi
cat "$out/baseline-failure.txt"
# Optional instrumentation uses the same RAM-only executable. Leak detection is
# disabled explicitly; no LeakSanitizer or real firmware allocation claim.
if [[ ${SANITIZE:-0} == 1 ]]; then
  "$cc" "${flags[@]}" -fsanitize=address,undefined -fno-omit-frame-pointer \
    "$source" -Wl,--gc-sections -o "$out/sanitized"
  check_symbols "$out/sanitized"
  ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 "$out/sanitized"
fi
printf '%s\n' 'Verified: no engine/GPU transaction symbols in hosted executables.'
