# 기존 진단 거부 기록 확인

[English](EXISTING-CAPTURE-TEST.en.md) | **한국어**

#114, #160의 오프라인 보고 테스트입니다. 이미 보유한 DIAG 파일만 사용합니다.
새 EFI 부팅, GPU 접근, 관리자 권한, 설정 변경은 필요하지 않습니다.
원본 캡처 파일을 수정하지 않고 읽습니다.

압축을 푼 테스트 소스 폴더에서 PowerShell을 열고 실행하세요.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-existing-captures.ps1
```

메시지가 표시되면 기존 `DIAG00.TXT`, `DIAG01.TXT`가 있는 폴더를 입력하세요.
실행 정책으로 차단되면 정책을 바꾸지 말고 알려주세요.
`python.exe`가 stub/별칭이면 기존에 사용하는 정상 Python 3 실행 파일의 경로로
`-Python "C:\path\to\python.exe"`를 추가하세요. 검사기를 실행하기 전 인터프리터를
확인하며 PATH 변경은 필요하지 않습니다.

해당 이슈에 보고된 정확한 거부 표식이 있으면 `invalid_graph` 대신
`probe_envelope_refused`가 표시되어야 합니다. 전체 상태는 `invalid_data`,
`write_eligible: false`, `hardware_tested: false`로 유지됩니다.
기록된 거부 사유만 설명하며 나머지 로그를 검증하거나 프로필 사용을 허가하지
않습니다. 다른 오류나 상충하는 표식에는 여전히 `invalid_graph`가 표시될 수 있습니다.
#170처럼 허용 범위 거부와 GOP 정보 누락 표식 두 개 및 불완전/실패 종료 표식이
정확히 기록된 경우 `multiple_capture_failures`가 예상됩니다. 두 원인을 입증하는 결과는 아닙니다.

새 `문서\GPU-Unlock-Capture-Check-...` 폴더의 **report.json, result.json**을
검토한 뒤 첨부하세요. 드라이버/PROM 원본이나 전체 시스템 보고서는 올리지 마세요.
실패하면 생성된 파일 또는 개인 경로를 지운 짧은 오류를 보내고 중단하세요.
EFI를 다시 부팅하지 마세요.

#104의 이 분류 테스트에는 보고된 envelope 거부가 있는 기존 DIAG00.TXT
한 개면 충분합니다. PROM 또는 IMG 파일은 필요하지 않습니다. 캡처 수 경고를
없애려고 두 번째 캡처를 수집하지 마세요. Windows/화면 자동 복귀는 사용자
관찰이며 프로필 또는 unlock 증거가 아닙니다. 현재 활성화된 Secure Boot를 유지하세요.

#75의 현재 생성기는 aggregate console graph를 지원합니다. 이전 two-GOP
거부는 현재의 일괄 규칙이 아닙니다. 합성 root-UID1 aggregate 회귀는 보고된
SS0/SS1 쌍에서 구조 pin을 유지하고 route drift를 거부합니다. 소스 동작이며
실제 캡처 통과나 레지스터 변화의 무해함을 증명하지 않습니다. 저장된 캡처와
이미지에 같은 offline checker를 사용하세요. 새 cold-monitor 캡처, BIOS/드라이버
변경, 다른 프로필 차용 또는 하드웨어 실행은 요청하지 않습니다.

#52의 non-aggregate 생성기는 ConOut 기록 누락, EFI_NOT_FOUND/경로 없음,
중복 기록, 존재하지만 불일치하는 경로를 구분합니다. 인식된 aggregate는 기존
전체 live ownership 계약을 사용하며 NVRAM 변수를 만들지 않습니다. NVRAM 부재만으로
승인하지 않고 잘못된 combo ID는 계속 거부합니다. 기존 캡처만 재검사하세요.

#20의 공개된 정제 캡처를 데이터로 읽었습니다. 물리 GOP1개,2206/161210de,
GA102/10240MiB이며 회귀는3090 승인을 차용하지 않고 outside_scope/gpu_scope를
유지합니다. 저장 캡처1개이면 capture_count도 유지합니다. 진단 컴파일 플래그
GU_CONSOLE_AGGREGATE는 관측된 aggregate graph의 증거가 아닙니다. count를 없애려고
새 부팅을 하지 마세요. 기존 증거가 소스 검토 입력이며 armed profile은 아닙니다.
