# Issue17 Windows 대상 분리

기존 PCI 부모 판독기는 case17의 정확한 ID를 사용합니다.
2204/40411458과1e04/12fa10de가 각각 하나씩 있어야 선택하며,
대상이 아닌2c02/41781458의 부모를 읽지 않습니다. 누락/중복이면 중지합니다.
모의 테스트는 두 대상, 제외된5080, 중복 및 누락을 검사합니다.

```powershell
powershell -NoProfile -File .\tools\test-pci-parents.ps1 -Case 17
```

ReadStatus observed와 두 개의 제한된 Windows 부모 연결 또는
unavailable/target-not-unique를 예상합니다. 표시된 Documents 폴더의 검토한
pci-parents.json만 반환하세요. 원본 장치 인스턴스 경로는 제외합니다.
관리자 권한, Python, 드라이버 변경, PCI config/MMIO, EFI, 재부팅은 없습니다.
카드, 케이블과 설정을 유지하세요. 차단/실패하면 중지하고 개인 정보를 제거한
짧은 오류를 보내세요. 통과하려고 카드를 제거하지 마세요.

다중 대상 격리 검토를 위한 Windows 연결 정보이며 물리 슬롯, 링크 폭,
펌웨어 소유권, 독립 release 또는 unlock을 증명하지 않습니다.
TU1021e04는 현재 generic probe 허용 목록 밖입니다. vendor 함수 이름은
제품군 지원의 근거가 아닙니다. 이 테스트는 GPU를 승인하지 않습니다.
