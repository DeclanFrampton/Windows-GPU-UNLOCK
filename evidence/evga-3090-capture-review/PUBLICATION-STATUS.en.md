# EVGA profile publication status

[í•œêµ­ì–´](PUBLICATION-STATUS.ko.md)

The attended exact-machine unlock is demonstrated. This PR is available for review; the reusable USB-free unlock profile is not complete.

On 2026-10-29 the contributor reproduced all seven reconciliation checks: reviewed SULK01 hash, slot 8, transaction return, asset release, Windows-ready, two complete captures and exact original USB reservation. The reservation and execution evidence remain on their respective volumes. No history has been reset and slot 9 is build-only.

The revised temporary firmware-option cleanup completed on the contributor machine and a later read showed the option absent and BootNext clear. The original boot entries remained equal to backup. This does not prove general firmware recovery or explain the earlier failure.

Before calling the reusable profile complete:

- Completed: contributor confirmed both Linux and Windows boot normally after cleanup with USB removed.
- Completed: contributor confirmed the supplied benchmark was after SULK01 and before any further reboot. This is operator-confirmed timing.
- Implement cross-volume attempt progression using authenticated reviewed evidence without resetting reservations or allowing replay.
- Integrate a USB-free unlock launch and its one-shot gating, collection and cleanup; qualify the full path on the exact machine.
- Add focused regression coverage for the new cleanup execution path, native deletion arguments and partial failures. Existing 18 mocks do not cover the new execution path.
- Reconcile superseded guide text, provide matching English/Korean final instructions, and complete maintainer review.

Local checks on 2026-10-29: preparation-wrapper fixtures and real firmware-entry fixtures passed with native firmware/storage mocked. Contributor package build passed PE checks and 24 host cases. These checks do not establish USB-free hardware unlocking.
