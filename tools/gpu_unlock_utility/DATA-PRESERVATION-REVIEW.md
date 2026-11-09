# Data-preservation companion for PR #335

This patch is based on contributor head `db5c9209d6f88d6de4a4cbff8b8e3612022e243a`
of [PR #335](https://github.com/windows-GPU-UNLOCK/Windows-GPU-UNLOCK/pull/335).
It fixes bounded offline file-handling defects. It is not approval of the entire
utility, an unlock release, or new hardware evidence.

## Changes

- Synthetic fixture generation refuses existing destinations, stages a new set,
  and preserves an output folder that appears during generation. Logs and
  metadata identify the output as synthetic and ineligible as hardware evidence.
- The GUI generates fixtures in a separate unique folder rather than the
  currently selected hardware-capture directory. Python failures propagate.
- Cache cleanup removes only known archive files created by the current run.
  Existing archives, unrelated files and caller-owned extraction folders survive.
- Existing mismatched or symlinked archives are refused. Downloads use unique
  temporary files and exclusive final-file creation. A failed final copy removes
  only its newly created partial file.

Hash pins, source parsing and final firmware validation are unchanged. Tests use
fake bytes and mocked network responses, never real firmware downloads.

## Verification

On Linux with Python 3.12.14:

```sh
python -m unittest discover -s tools/gpu_unlock_utility -p test_data_preservation.py -v
python -m unittest discover -s tools -p 'test_*.py' -q
python -m unittest discover -s benchmark -p 'test_*.py' -q
python -m unittest discover -s research/profile -p 'test_*.py' -q
```

22 data-preservation, 14 existing tools, 28 benchmark and 101 profile tests pass.
The preservation tests reproduce overwriting/deletion on the unmodified PR head.
GUI assertions inspect wiring only; native Windows PowerShell/WPF behavior is
untested. No GPU, CUDA library, EFI, registry, USB, boot or security-setting
operation was executed. Existing release manifests were not refreshed.

## Remaining blockers outside this patch

The original utility still permits its diagnostic staging path to target any
mounted FAT32 volume without the established USB/system-partition checks.
The original `GuLogFlush` also treats positive EFI warning statuses as success,
contrary to the headless non-success rejection policy. Both need separate fixes
and regression tests before the original PR can be treated as ready.

The cache and synthetic-fixture fixes do not establish hardware compatibility,
safe recovery, source authenticity, or the broader PR's claimed performance.
