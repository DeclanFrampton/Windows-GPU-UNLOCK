# Further offline diagnostic research

Date: 2026-10-25. External source remains pinned to
`4e7fefcc4923f9e083d5324dc75a7d2f906af77f`. No device access, driver loading,
firmware image, boot change or remote submission is involved.

## Guard-backed ROM parser execution

[host_guarded_rom_cases.c](host_guarded_rom_cases.c) adds CPU-only tests against
the same parser and synthetic fixture used in [HOST-TESTS.md](HOST-TESTS.md).
It uses Windows virtual-memory APIs to put the end of each declared input
immediately before `PAGE_NOACCESS`; the input page is `PAGE_READONLY` during
parsing and the output structure has canaries. No device handle is opened.

| Family | Calls |
|---|---:|
| Every declared fixture length, 0 through 4096 | 4,097 |
| Each of 32,768 individual bits flipped in the 4096-byte fixture | 32,768 |
| Token/table/descriptor/range boundary values | 27 |
| BIT header-size/stride/count values with checksum repair where applicable | 12 |
| Total | 36,904 |

Observed result: **32,268 structurally accepted, 4,636 rejected; zero exceptions,
no changed output canaries**. All successful outputs also satisfy image,
signature, DMEM, PKC and interface-range constraints checked by the harness.
Input writes would raise an exception because the input page is read-only.
Accepted mutations are expected: most fixture bytes are not structural fields.
Structural acceptance does not authenticate any firmware signature.

[guarded-host-results.json](guarded-host-results.json) records this run plus the
six existing passing console targets. It supersedes older execution snapshots
for the current runner. Reproduce using the command in HOST-TESTS.md; the guarded
target is included automatically. No EFI is generated.

To avoid a large diagnostic log per mutation, only the guarded target replaces
the parser's diagnostic macros with no-ops while retaining return expressions.
The non-guarded parser tests keep the original logging. This target also needs
MSVC warning 5105 disabled for the installed Windows SDK's macro definition,
in addition to the documented synthetic-fixture byte/checksum warnings. No
upstream source was edited.

Limits: the full-size 4096-byte fixture abuts both inaccessible pages on the
tested 4096-byte-page host. Shorter slices end at the upper inaccessible page,
but bytes before their start can remain mapped, so this is primarily an overread
and input-write check for truncations. It is deterministic bounded mutation,
not coverage-guided fuzzing, a sanitizer run, exhaustive format validation,
real-ROM analysis or a claim about hardware safety. Errors are caught inside
the console test process; no firmware or GPU transaction is attempted.
