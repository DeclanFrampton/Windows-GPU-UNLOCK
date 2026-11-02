# Existing EDID binding review (#144)

```powershell
powershell -NoProfile -File .\tools\test-existing-edid.ps1
```

Select the existing folder of complete DIAG00/01.TXT captures. Existing Python3
only; -Python may select an installed known-good executable. No IMG/PROM needed.
The reader uses the common complete-graph and binding parsers, supports CRLF,
and reports BY_DRIVER edges for EDID_DISCOVERED and EDID_ACTIVE separately.
Counts are observed edges, not unique driver images. Exported GUID/version is
firmware metadata, not a release fingerprint or verified source identity.

For #144's disclosed EDID_DISCOVERED owner, expect version16,
605ced2c-583b-4171-9311-aa6e146b1a4b, reviewed_mouse_identity_match=false.
That means bound with a different identity, not absent. NoEdidDriver and detach
authorization remain false. It cannot prove whether a driver survived release.
Missing/ambiguous bindings or incomplete captures stop the review.

Return only reviewed edid-review.json from the printed Documents folder.
If unavailable/blocked/failing, stop and return a short sanitized error.
Do not create new captures, relax GU_NO_EDID_DRIVER gates, change settings or
boot firmware. Raw captures, pointers, images and PROM remain private.
Local tests use synthetic ownership data with the reported GUID/version;
they do not independently verify the Dell hardware result or admit2560.
