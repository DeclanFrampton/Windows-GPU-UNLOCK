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

해당 이슈에 보고된 정확한 거부 표식이 있으면 `invalid_graph` 대신
`probe_envelope_refused`가 표시되어야 합니다. 전체 상태는 `invalid_data`,
`write_eligible: false`, `hardware_tested: false`로 유지됩니다.
기록된 거부 사유만 설명하며 나머지 로그를 검증하거나 프로필 사용을 허가하지
않습니다. 다른 오류나 상충하는 표식에는 여전히 `invalid_graph`가 표시될 수 있습니다.

새 `문서\GPU-Unlock-Capture-Check-...` 폴더의 **report.json, result.json**을
검토한 뒤 첨부하세요. 드라이버/PROM 원본이나 전체 시스템 보고서는 올리지 마세요.
실패하면 생성된 파일 또는 개인 경로를 지운 짧은 오류를 보내고 중단하세요.
EFI를 다시 부팅하지 마세요.
