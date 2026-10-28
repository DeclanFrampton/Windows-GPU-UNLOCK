# EVGA20 second unlock transaction

[English](EVGA20-RESULT.en.md) | [한국어](EVGA20-RESULT.ko.md)

After the post-shutdown baseline measurement, Movian ran the second attended unlock attempt and reported Windows booted directly after brief screen flashes. EVGA20 records admission success with entry SS0 `0x32053014`, SS1 `0x7`, pre-FLR target SS0 `0x88888888` and SS1 `0x8`, successful FLR, transaction result zero, no recorded fault, quiesced resources and no retained mappings. Cleanup, captures and ready-Windows were successful. The post-FLR SS1 value is split across two lines; the following line contains the remaining digits.

This is a second recorded successful transaction on the same machine. The uploaded three-trial benchmark passed the offline comparison against the post-shutdown run, with medians FP32 26.452055 (+0.15%), FP16 122.797549 (+89.61%), BF16 123.135526 (+90.37%) and TF32 64.083906 (+94.40%) TFLOPS. Same-machine confirmation was supplied based on the contributor's reported sequence. The first FP16 trial was 86.620022 TFLOPS versus 122.797549 and 123.197342 in the other two; its cause is unknown and a repeat benchmark was requested. Retain this outlier rather than discarding it. This does not establish an unattended or reusable boot launcher, restart behavior, full correctness or long-term stability.

The raw log remains private. SHA-256: `0d793ac0913e13f1aa786026743aa33ddcb6b5fe79fe0975a1269b5c378b9053`.
Benchmark ZIP SHA-256: `d544db7b705c2f61bd79ad8b1ec60ee17910bfb60f87e1be7486c9cc528437e5`.
