# Windows host validation

Run from pinned source with an existing Python3, clang and MSVC/Windows SDK:

```powershell
powershell -NoProfile -File .\research\pci-decode\test-decode-sync.ps1
```

If discovery needs help, use -Python, -Clang or -VcVars with tools already
installed. No installs, PATH persistence or policy changes are requested.
The script sets the compiler environment only in its child process, runs the
existing shared core/adapter/capture suites and all compiled guard mutations,
and writes a new Documents/GPU-Unlock-Decode-Host-*/run/summary.json.
Expect all host suites PASS and21 compiled mutations detected on the PR139
merged source. These are native Windows RAM-only mocks, not EFI ABI/hardware
proof, production integration, profile admission or Windows-return testing.
Return only reviewed summary.json if useful; the contributor need not repeat
tests already run by the maintainer. Missing tools or failure: stop and return
the short sanitized error. No capture, firmware, USB staging or reboot.
