# EVGA profile publication status

[í•œêµ­ì–´](PUBLICATION-STATUS.ko.md)

The attended exact-machine unlock is demonstrated. This PR is available for review; the reusable USB-free unlock profile is not complete.

On 2026-10-29 the contributor reproduced all seven reconciliation checks: reviewed SULK01 hash, slot 8, transaction return, asset release, Windows-ready, two complete captures and exact original USB reservation. The reservation and execution evidence remain on their respective volumes. No history has been reset. Slot 9 payloads are staged; the contributor registered Boot7E00 with BootNext clear and the attempt unarmed. The new run script prepares receipt/reservation and BootNext-last selection; live execution is pending.

The revised temporary firmware-option cleanup completed on the contributor machine and a later read showed the option absent and BootNext clear. The original boot entries remained equal to backup. This does not prove general firmware recovery or explain the earlier failure.

Before calling the reusable profile complete:

- Completed: contributor confirmed both Linux and Windows boot normally after cleanup with USB removed.
- Completed: contributor confirmed the supplied benchmark was after SULK01 and before any further reboot. This is operator-confirmed timing.
- Implemented for the reviewed slot 8 to 9 transition: cross-volume evidence checks, create-new reservation/receipt and replay refusal. Live arming is pending; general progression is not yet published.
- Integrated the next USB-free boot test, one-shot arming, evidence ZIP collection and exact-owned cleanup in run-shared-esp-second.ps1. Qualify the full hardware path before publication; see [the next run](SHARED-ESP-SECOND-RUN.en.md).
- Local coverage now includes the real SULK02 wrapper with a RAM-native fake, deletion attributes 7, cleanup/refusal, preserved ZIPs, BootNext-last order and partial failures. Native mocks do not establish actual firmware semantics or recovery.
- Reconcile superseded guide text, provide matching English/Korean final instructions, and complete maintainer review.

Local checks on 2026-10-29: preparation-wrapper fixtures and real firmware-entry fixtures passed with native firmware/storage mocked. Contributor package build passed PE checks and 24 host cases. These checks do not establish USB-free hardware unlocking.
