# EVP11 트랜잭션 완료; 정리 대기

[English](EVP11-RESULT.en.md)

기여자가 직접 압축한 결과에는 예상 파일 네 개가 있습니다. 로그 SHA256 `386a2b17d30aa2eb18e36fd8d742e84518be69e2093214a863f40c3191b5f768`, 영수증 `00bf38e9f2d2e2fe5a3b83293d7c4d57ce741d118366628f2eea988efe8bf58a`, 런타임 마커 `c81ed25e0ed465df4a3813ac40781f6d0fb46f06fe899d4ed4fb6b4666c70aca`는 보고한 수집 결과와 일치합니다. 패키지 EFI 해시는 `c4f3360abeab91c1345d5fe35e9d2992b1dec87a99a78357dddb6b29604e2609`입니다.

진입 SS1=7로 허용되었고 FLR 전 SS0=88888888, SS1=8이었습니다. 트랜잭션 result=0, contained=0, started=1, quiesced=1, fault=0, retained=0, maps=0, FLR=1입니다. 성공 복귀, close, 자산 해제, Windows 준비 및 캡처 두 개가 기록되었습니다. 운영자는 Shift+G 후 Windows가 로드되었으며 시험 전 USB 제거를 보고했습니다. 완전 종료 여부는 명시적 재확인이 필요하며 단일 성공이 원인이나 일반 신뢰성을 입증하지는 않습니다.

수집은 Success=true이지만 기존 부팅 항목 변경으로 CleanupCompleted=false입니다. 비교 검토 전 정리 조건 완화나 재준비를 하지 마세요. 자동 ZIP이 보이지 않아 결과 폴더를 직접 압축했다고 보고했으며 표시된 ZIP이 보이지 않은 이유는 알 수 없습니다.

재부팅 없이 저장소 루트 관리자 PowerShell에서 실행하세요.

```powershell
./research/profile/check-evp11-session.ps1
```

정확한 성공 증거를 확인하고 기존 결과 ZIP을 보존하거나 없으면 재구성한 뒤 펌웨어 항목을 읽어 비교하고 기존 해시 고정 GPU 벤치마크를 EVP11 이름으로 실행합니다. 검사/벤치마크 ZIP 두 개를 보내세요. 펌웨어 쓰기, 정리, 재준비나 재부팅은 없습니다. 벤치마크는 GPU를 사용하며 실패 시 부분 결과를 보존하고 자동 반복하지 않습니다. 중간 재부팅, 완전 종료 방식과 USB 부재를 알려주세요. 오류 시 오류와 이미 생성된 ZIP을 보내세요.

가짜 펌웨어/저장소 및 모의 벤치마크를 사용한 결합 검사에서 PowerShell 7과 5.1이 통과했습니다. 실제 벤치마크나 정리 성공을 대신하지 않습니다.
