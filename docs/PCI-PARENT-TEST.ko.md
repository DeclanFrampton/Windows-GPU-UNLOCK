# Windows PCI 부모 연결 (#108)

고정 소스를 압축 해제한 폴더의 일반 Windows PowerShell에서 실행하세요.

```powershell
powershell -NoProfile -File .\tools\test-pci-parents.ps1
```

현재 디스플레이 목록과 유일한 2208/40811458 대상 및 최대 16개 상위 장치의
DEVPKEY_Device_Parent만 읽습니다. 숫자 PCI ID/서브시스템과 연결 순서만 내보내며
원본 인스턴스 경로, 일련번호, 이름, 오류 본문은 제외합니다. OCuLink 커넥터,
펌웨어 토폴로지, 소유권, release 또는 unlock 증거가 아닙니다.
Secure Boot를 활성 상태로 유지하세요. Python, 관리자 권한, 펌웨어 덤프,
PCI config/MMIO 접근, 드라이버 변경, EFI 준비 또는 재부팅은 필요하지 않습니다.

표시된 Documents 폴더의 검토한 pci-parents.json만 반환하세요. 대상이 유일하면
observed와 연결 하나를 예상합니다. unknown, unavailable, target-not-unique,
cycle, hop-limit도 허용되는 중지 결과입니다. 이를 없애려고 하드웨어 이동/재연결,
권한 상승, 설정 변경 또는 EFI 재시도를 하지 마세요. 스크립트 정책이 차단하면
개인 경로를 제거한 짧은 오류만 보내세요.

개발자 모의 회귀 테스트는 -SelfTest입니다. 로컬 Windows 내보내기 검증은
제보자의 토폴로지 또는 하드웨어 호환성을 증명하지 않습니다.
