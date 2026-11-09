# Boot splash: CPU-only host regression tests

This harness includes the actual `boot-splash.c` and `sha256.c` in one hosted
translation unit, exposing their static helpers for focused tests. It does not
copy a decoder or substitute a hash implementation. No production source changes
are needed. Initial review base: PR #254, commit
`e1c2b48c2bcb29342b68774098379750fb282bb2`, tree
`9b1b0b028465ad32cef4c7bfcf8bf825a792282f`.

## Run

From the repository root, with installed GCC, a POSIX shell and `timeout`:

```sh
sh internal-boot/boot/tests/splash-host/run.sh
SANITIZE=1 sh internal-boot/boot/tests/splash-host/run.sh
```

The runner compiles only this test translation unit, using existing EDK2 headers.
It creates and deletes a private temporary build directory, uses a 60-second
execution limit per binary, and invokes no other repository scripts. It refuses
an existing production `internal-boot/boot/build/headless/splash-contract.h` to
avoid accidentally consuming a real generated asset contract. A clean worktree
is recommended. Compilation with `-ffreestanding` must fail with the explicit
hosted-build diagnostic; the runner checks this using syntax-only compilation.

The synthetic asset is constructed entirely in RAM: 112 independent LZ4 blocks,
each expanding to a 1920x1080 RGB565 frame of byte value 0x5a. Each block has one
literal, a distance-one overlapping match, then five final literal bytes.
`synthetic-contract.h` contains its independent Python hashlib SHA-256 pin and
exact length. The actual production hash implementation checks that pin. The
runner copies this test contract only into its temporary include tree.

For independent pin reproduction (standard Python only):

```python
import hashlib, struct
n = 1920 * 1080 * 2 - 6 - 4 - 15
block = bytes([0x1f, 0x5a, 1, 0]) + bytes([255]) * (n // 255)
block += bytes([n % 255, 0x50]) + bytes([0x5a]) * 5
header = struct.pack('<118I', 0x414d5547, 0x31305854, 1920, 1080, 112,
                     *[i * len(block) for i in range(113)])
asset = header + block * 112
print(len(asset), hashlib.sha256(asset).hexdigest())
```

## Covered

- Full literal output and overlapping match output; malformed literal/match
  lengths, missing offsets, zero/past-output backreferences, truncated sources,
  empty input and literal/match output overflow. Output sentinels are checked.
- Header identity, dimensions/count/initial offset, non-increasing offsets,
  oversized blocks, overall offset limit and asset-length pin mismatch.
- Short header and both payload reads, read/open/close errors, extra trailing
  data and hash mismatch. All four pool allocations fail independently, both
  with an error and success-with-null. Fake pool ownership counters return to
  zero after every scenario.
- Begin, duplicate Begin, unchanged-frame tile suppression, timer ticks,
  countdown Esc (scan code and Unicode), input error, both event-creation and
  timer-arming failures, wait error, burst completion, teardown and repeated
  teardown. No graphics callback occurs through the tested post-End calls.
- Geometry drift, invalid pixel format, BLT-only fallback, missing optional
  timestamp protocol and BLT failure.
- Direct framebuffer validation for dimensions, pitch, pixel format, alignment,
  size and address overflow, plus native-size ordinary RAM writes with sentinel
  boundaries, known RGB565-to-BGR output and a harness-only vector-store counter. The counter
  checks every native full-frame store, zero stores for an unchanged delta, and
  exactly four vector stores for a single changed pixel in a 16-pixel group.

## Important coverage limits

- This is not a firmware, hardware, timing, EFI ABI or integration test. All
  service functions are local callbacks and all framebuffer storage is allocated
  ordinary RAM. No device, filesystem protocol outside the mocks, EFI image,
  driver, USB, ESP, GPU, registry, firmware asset or contributor utility is used.
- GCC does not implement Clang's `__builtin_nontemporal_store`. Only in this test
  translation unit it is replaced with an ordinary vector store plus a harness-only counter. Native x86
  store fences execute on RAM. Non-temporal store semantics, cache behavior and
  performance/selection thresholds are **not validated**.
- Direct-path selection, scaled/doubled drawing, partial changed-tile runs,
  timestamp wrapping/invalid properties, multi-GOP discovery/fallback,
  allocation-free errors and event-close errors are not comprehensively tested.
  Fake BLT checks source/destination ranges but does not emulate GOP rendering.
- The host types/ABI come from the existing EDK2 headers; they do not establish
  that the real firmware callbacks obey their contracts. The fake wait queue is
  bounded/synchronous, not concurrent firmware scheduling.
- The surrounding handoff/driver-release code is not linked. Thus post-End
  silence in this harness is **not proof of driver-release ordering**, nor a
  substitute for reviewing the actual call sites.
- ASan/UBSan are supplementary checks. LeakSanitizer is explicitly disabled
  (`detect_leaks=0`) due to environment constraints. Pool/event accounting is
  asserted by the harness; no LeakSanitizer-clean claim is made.

## Recorded validation

GCC 14.2.0, Linux x86-64, 2026-11-09:

- `-std=c11 -O1 -g -Wall -Wextra -Werror -fshort-wchar`: passed.
- Hosted-build guard: expected freestanding refusal passed.
- Normal and `-fsanitize=address,undefined -fno-omit-frame-pointer` runs:
  `PASS 10369663 assertions` each. Most assertions compare output pixels, not
  distinct test cases.
- An additional `-O0 --coverage` run with `gcov -b -c -n` reported for the actual
  `boot-splash.c`: 76.05% of 309 executable lines, 80.75% of 478 branches executed,
  64.23% of branches taken at least once. These figures are not total validation
  of the source, particularly the paths listed above.
