# EVP11 completed transaction; cleanup pending

[한국어](EVP11-RESULT.ko.md)

The contributor's manually packaged results contain the expected four files. EVP11 log SHA256 `386a2b17d30aa2eb18e36fd8d742e84518be69e2093214a863f40c3191b5f768`, receipt `00bf38e9f2d2e2fe5a3b83293d7c4d57ce741d118366628f2eea988efe8bf58a` and runtime marker `c81ed25e0ed465df4a3813ac40781f6d0fb46f06fe899d4ed4fb6b4666c70aca` match the reported collection. Package EFI hash is `c4f3360abeab91c1345d5fe35e9d2992b1dec87a99a78357dddb6b29604e2609`.

Entry admission passed with SS1=7. Pre-FLR selectors were SS0=88888888 and SS1=8. Transaction result=0, contained=0, started=1, quiesced=1, fault=0, retained=0, maps=0 and FLR=1. Successful transaction-return, close-return, asset release, Windows-ready and two captures are recorded. The operator reports Windows loaded after Shift+G and reported removing USB beforehand. Full shutdown versus restart must still be explicitly confirmed; one success does not establish causation or general reliability.

Collection reports Success=true but CleanupCompleted=false because an existing boot entry changed. Do not weaken cleanup or rearm until the current entry comparison is reviewed. The operator reported no automatically visible ZIP and manually archived the result directory; why the printed ZIP was not visible is not established.

Next, without rebooting, administrator PowerShell at the repository root:

```powershell
./research/profile/check-evp11-session.ps1
```

This checks the exact successful log/receipt/marker, preserves or reconstructs the collected ZIP if missing, reads the current firmware entry comparison and runs the existing hash-pinned GPU benchmark labelled EVP11. It prints inspection and benchmark ZIP paths; send both. No firmware writes, cleanup, rearm or reboot occur. The benchmark does use the GPU and can fail like the existing benchmark; preserve partial output rather than retry automatically. Report any intervening reboot, full-shutdown method and USB absence. If the script fails, send the error and any ZIP already produced.

The combined workflow passes with fake firmware/storage and a synthetic benchmark in PowerShell 7 and Windows PowerShell 5.1. These checks do not substitute for the live benchmark or cleanup result.
