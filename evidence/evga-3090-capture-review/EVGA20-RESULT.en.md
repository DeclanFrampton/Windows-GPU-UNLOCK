# EVGA20 second unlock transaction

[English](EVGA20-RESULT.en.md) | [한국어](EVGA20-RESULT.ko.md)

After the post-shutdown baseline measurement, Movian ran the second attended unlock attempt and reported Windows booted directly after brief screen flashes. EVGA20 records admission success with entry SS0 `0x32053014`, SS1 `0x7`, pre-FLR target SS0 `0x88888888` and SS1 `0x8`, successful FLR, transaction result zero, no recorded fault, quiesced resources and no retained mappings. Cleanup, captures and ready-Windows were successful. The post-FLR SS1 value is split across two lines; the following line contains the remaining digits.

This is a second recorded successful transaction on the same machine. A repeat post-attempt benchmark has been requested; the performance result is pending. This does not yet establish an unattended or reusable boot launcher, restart behavior, or long-term stability.

The raw log remains private. SHA-256: `0d793ac0913e13f1aa786026743aa33ddcb6b5fe79fe0975a1269b5c378b9053`.
