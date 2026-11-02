# EDID-bound multi-child runtime review

Issue114's returned JSON confirms three children versus an allowed count of two.
The private graph itself has not been independently reviewed. No monitor change
or additional boot is requested.

The non-aggregate GU_HEADLESS_RESEARCH FullConsumers branch already iterates up
to four children, validates their paths/PCI parent and same EDID owner, and
requires secondary children to lack GOP/text consumers. The aggregate fallback
requiring one child is a different preprocessor branch. The generator and local
header still explicitly refuse EDID-bound counts above two. Runtime capacity
alone does not justify relaxing those guards.

The existing shared RAM-only runner now accepts optional --card and --children
selectors, preserving its default matrix and all existing exclusions. For the
baseline, with the already configured host compiler environment:

```text
python -I research/profile/test_local_release.py --card 0x250410de --children 2 --output <new-output-folder>
```

Eight GA106 cases passed locally: bus1/2b, PCI command2/3, EDID/no-EDID. Each
EDID case passed6456 checks; each no-EDID case passed4961. This is existing
two-child production-code behavior on synthetic RAM fixtures, not three-child
validation, vendor firmware execution or contributor hardware evidence.

Next: validate the exact three-child EDID contract and negative mutations in
this same harness before proposing any generator/header admission extension.
No guard is changed here and no contributor rerun is requested.
