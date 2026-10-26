/* GPL-2.0-only. Probe interface; CAPTURE layout must match diagnostic.c. */
#pragma once
#include <Uefi.h>
#include <Protocol/SimpleFileSystem.h>
#include "../unlock/machine-profile.h"
#include "diagnostic.h"
EFI_STATUS GuProbeGpu(EFI_SYSTEM_TABLE *t,CAPTURE *c);
#if defined(GU_AD104_EDID_TEST) || defined(GU_AD104_TEXT_TEST)
EFI_STATUS GuEdidExperiment(EFI_SYSTEM_TABLE *t,EFI_FILE_PROTOCOL *log);
#endif


#ifdef GU_AD104_TEXT_TEST
extern BOOLEAN GuTextOutputDisabled;
#endif
