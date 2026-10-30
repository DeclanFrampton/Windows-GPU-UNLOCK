# 재사용 SharedEsp 프로필 검증 완료

[English](EVP12-RESULT.en.md)

EVP12는 실패 예외 없는 기본 Rearm, 새 슬롯/영수증, 참석형 트랜잭션 성공, 직접 Windows 복귀, 수집 및 정리를 입증합니다. 반환한 로그/영수증/런타임 마커 해시가 보고값과 일치합니다. 완료 캡처 두 개, FLR 전 SS0=88888888/SS1=8, result=0, fault=0, retained=0, maps=0, FLR=1 및 성공 close/자산 해제/Windows 준비가 기록되었습니다. 수집은 CleanupCompleted=true이며 증거/정리 오류가 없습니다.

EVP11에서 같은 세션 벤치마크, 정리와 이후 Boot0000 정상 재부팅, 빈 BootNext, 임시 항목 부재 및 기존 항목 동일을 별도로 확인했습니다. EVP12의 새 벤치마크나 추가 일반 재부팅을 주장하지 않습니다. EVP12 완전 종료/USB 부재 확인은 최종 전달에서 요청하며 성공 원인이 EVP10과 달랐던 이유를 입증하지는 않습니다.

**이 특정 장비에서 SharedEsp 재사용 흐름을 입증했습니다.** 완전 종료와 새로운 Shift+G가 필요합니다. 공유 프로필의 과거 장비 검증 표시가 이 범위를 기록하며 새로 빌드한 각 패키지는 실제 실행 전 HardwareTested=false를 유지합니다. 영구/무인 잠금 해제, Secure Boot 및 일반 장비 호환성은 입증하지 않았습니다. Usb/SeparateEsp 프로필도 제공하지만 새 재사용 패키지는 빌드/모의 검증만 완료했으며 이전 USB 기반 증거와 구분합니다. 관리자 승인은 대기 중입니다.

## 최종 전달 — 재부팅/GPU 시험 없음

브랜치를 업데이트한 뒤 저장소 루트 관리자 PowerShell에서 실행하세요.

```powershell
./research/profile/export-evga-profile-handoff.ps1
```

검증 ZIP과 EVP12 완전 종료/USB 부재 확인을 보내세요. 정확한 EVP12 성공 증거, 기존 EVP11 일반 부팅 영수증 및 현재 임시 항목/BootNext 부재를 확인한 뒤 요약, 프로필, 안내 및 검토한 벤치마크 요약만 저장합니다. 펌웨어 백업, 원시 덤프, 키나 실행 자산은 포함하지 않습니다. 로컬 파일만 만들며 설치, 펌웨어 쓰기, GPU 접근, 재준비나 재부팅을 하지 않습니다. 오류 시 보내고 상태를 보존하세요. 이번 검증 순서에 추가 EFI를 요청하지 않습니다.

원래 USB 예약, EVP10 실패 증거, 시도별 영수증과 비공개 복구 백업을 모두 보존하세요. 향후 검토된 사용은 `manage-evga-profile.ps1 -Action Rearm`, 완전 종료와 참석형 순서이며 영구 자동 설치가 아닙니다. 소비된 슬롯을 재사용하려고 기록을 지우지 마세요.

근거: [EVP12 증거](evp12-result.json), [EVP11 벤치마크](evp11-benchmark.json), [기술 검토](REUSABLE-PROFILE-REVIEW.ko.md). 이 범위로 관리자 검토가 가능한 PR이며 관리자 승인 자체를 의미하지 않습니다.
