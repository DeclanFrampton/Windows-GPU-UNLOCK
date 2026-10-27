# AD104: shared consumers and the unlock proof boundary

English | [í•œêµ­ì–´](AD104-UNLOCK-EVIDENCE.ko.md)

## Latest physical result

[Twelfth run](AD104-TWELFTH-RESULT.en.md): text/GOP-consumer/EDID removal followed
by direct owner-child Stop passed. Fresh enumeration found the old GOP child
absent; input and user-confirmed Windows return succeeded. Three relationships
remain: PCI ownership and both pointer relationships. All ten PCI snapshots are
identical, command `0007`/BME enabled. Parent release and unlock remain unproven.
Earlier sections below describe dated observations.

## Actual graph replaces the simplified fixture

The fifth capture contains 140 non-passive open records. The
[sanitized active-consumer report](ad104-active-consumers-evidence.json) identifies:

| Image | GPU-related active role | Other observed active role |
| --- | --- | --- |
| IMG29 | PCI owner and display child relationship | none in this snapshot |
| IMG14 | Simple Text Output owner and console-child relationship | none in this snapshot |
| IMG17 | GOP consumer | none in this snapshot |
| IMG08 | EDID Discovered consumer | Simple Pointer and Absolute Pointer on the console |

This mapper now requires the child to expose GOP and share the PCI owner's
agent. It ignores passive opens, handles null-controller application-exclusive
opens separately from driver relationships, and reports opened-protocol handles
without confusing them with each edge's ControllerHandle. These are offline
joins, not a complete runtime release preflight.

IMG08 spans three active edges on two opened-protocol handles. Its display and
pointer roles share a driver, so the four-role synthetic lifecycle fixture is
insufficient as an OEM release profile. The graph alone does not prove that
disconnecting its EDID role would destroy pointer input.

## Stop analysis and loaded-image layout

IMG08 Stop RVA is `0x1464`. Static inspection finds an EDID-probe success branch
that clears a byte at image RVA `0x546a`, closes the EDID open and returns.
The alternate pointer cleanup path includes list/counter updates and conditional
cleanup. This establishes controller-dependent branches in the captured code;
the shared flag's full meaning and effects remain unresolved. No callback ran.

These dumps are loaded-memory snapshots. IMG08's `.text` RVA is `0x1000` while
its original file raw pointer is `0x400`. Feeding that snapshot directly to a
file-layout disassembler produces incorrect decoding. `normalize-loaded-pe.py`
creates a separate private analysis copy whose section raw pointers select the
captured RVA bytes. It bounds sections, rejects overlaps/truncation, refuses an
existing output and preserves the original. This is not reconstruction of the
original vendor file and is never executed. IMG29's `.text` raw pointer already
equals its RVA (`0x2a0`), so the previous IMG29 Stop analysis is unaffected.

Reproduce offline with private paths:

```powershell
python research/profile/map-active-consumers.py C:\private\DIAG00.TXT --output C:\private\consumers.json
python research/profile/normalize-loaded-pe.py C:\private\IMG08.BIN --output C:\private\IMG08-analysis.bin
python -m unittest discover -s research/profile -p 'test_*.py'
```

Thirty-one Python tests pass. No new firmware was built or staged for this work.

## What would count as unlock evidence

1. Fresh runtime preflight must identify this controller, every relevant graph
   relationship, exact callback/code fingerprints and shared consumers. An old
   snapshot or matching board ID alone cannot authorize release.
2. A separately tested lifecycle experiment must establish callback outcomes,
   graph transitions, keyboard state, limited decode enable and partial-failure
   handling. A predicted BME change is not an observed cold GPU state.
3. Hardware cold-entry checks, including the required protected-memory state,
   must pass after release. We have not collected that register evidence yet.
4. A machine-specific transaction must report the intended state changes and
   independent readbacks, with bounded failure handling. No transaction has run.
5. Windows/driver recovery and controlled pre/post workloads must be verified
   under comparable conditions. An arithmetic-mode ratio measured entirely on
   the stock driver, or a faster result without state evidence, proves no unlock.

Current evidence establishes firmware topology, BAR shape, attribute masks and
a consistent captured two-image ROM chain. The [sixth physical run](AD104-SIXTH-RESULT.en.md)
also passed the implemented live fingerprint/topology consistency check. It
does not satisfy the live-release, cold-state or transaction gates above.
The [seventh physical run](AD104-SEVENTH-RESULT.en.md) additionally demonstrated
the predicted EDID release, actual post-disconnect keyboard input and Windows
return on this run. PCI command remains `0007`; BME is enabled. This is one
consumer transition, not successful release of the display stack or PCI owner.
The [text-driver analysis](AD104-TEXT-LIFECYCLE.en.md) identifies a conditional
GOP SetMode call during cleanup, so merely changing the target of the EDID test
would omit important postconditions.
No unchanged query/preflight repeat is needed.
An eventual live release test must explicitly describe possible lost display,
lost input and failure to return to Windows; it must not promise recovery that
has only been simulated.

## Distance to an unlock demonstration

| Gate | Current evidence |
| --- | --- |
| Exact identity, ownership and live discovery | Observed; EDID transition also demonstrated |
| Remaining text/GOP consumers and PCI-owner release | Text/GOP/EDID consumers demonstrated together; PCI owner not released |
| Limited decode enable and cold-entry/protected-memory admission | Not demonstrated; required register evidence absent |
| Machine-specific unlock transaction and independent state readback | Not run |
| Windows recovery and controlled stock/post-unlock workloads | Combined consumer return observed; no post-unlock workload exists |

These gates are not equally difficult and cannot support a meaningful percentage,
number of remaining boots or completion date. Cold-state admission or immutable
hardware restrictions could still prevent an unlock. The next decision should
follow evidence about text cleanup and its display effects, not confidence from
an unrelated successful callback. No additional boot is requested by this report.
