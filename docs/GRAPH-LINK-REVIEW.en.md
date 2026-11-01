# Existing graph relationship review

Use an existing graph-summary.json; no new capture, boot, settings change or installation.
The reader groups records by handle AND protocol. It exports display PCI identities and
GOP relationships only for a same-handle PCI/GOP or a PCI I/O BY_CHILD_CONTROLLER edge.
Edges under another protocol do not count. Unknown/ambiguous stays unresolved/ambiguous;
it is not evidence of absent hardware or proof of physical MUX routing. Handle pointers,
paths and arbitrary input text are not exported. Summary digest is copied as a claimed
capture identity, not recomputed against raw logs or hardware attestation.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\research\profile\test-graph-links.ps1
```
Enter the existing summary path. Uses existing Python, no compiler/admin requirement.
Expected graph-links.json in a new Documents folder; -OutputRoot accepts an existing
writable local root. Return only that reviewed JSON if requested. Originals stay unchanged.
Stop on incomplete/unresolved/ambiguous/error; preserve files and report the result,
not another EFI run. All physical-routing/release/hardware/write flags remain false.

Local tests cover protocol isolation, missing child edge, ambiguity, duplicate handles,
incomplete captures, scope and size refusal. Supplied130 summary has unique IntelA7A8
PCI-I/O child link;173 remains unresolved under this deliberately narrow rule. Both
owners report direct Windows return separately. No Ada MMIO/unlock admission or new
resource capture is authorized by these observations.
