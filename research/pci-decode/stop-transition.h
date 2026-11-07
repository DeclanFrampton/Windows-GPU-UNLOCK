/* GPL-2.0-only. Pure research observation policy; no restoration authority. */
#pragma once
#include "snapshot.h"

typedef enum {
  GU_DS_STOP_REFUSED,GU_DS_STOP_UNCHANGED,GU_DS_STOP_MEMORY_OFF
} GU_DS_STOP_RESULT;

/* Compare a corrected, complete pre-Stop baseline with a complete post-Stop
 * observation. MEMORY_OFF describes a delta; it does not authorize Enable,
 * establish ownership, authenticate snapshots or prove that Stop occurred.
 * Supplied snapshots must remain immutable throughout this pure call. */
GU_DS_STOP_RESULT GuDsStopTransition(const GU_DS_SNAPSHOT *Before,
                                    const GU_DS_SNAPSHOT *After);
