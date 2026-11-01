# MSI 실행 시점 감사 빌드 시험

[English](CHRISTIAN-RUNTIME-AUDIT.en.md)

Christian의 저장 입력 검사 아홉 개가 모두 true로 반환되어 기준 수집은 완료되었습니다. 새 `GU_MSI_RUNTIME_AUDIT`는 일반 관찰 프로브의 캡처 후 로드된 DriverBinding/이미지에 대해 MSI 콘솔 두 코드 해시, 버전, Stop RVA와 고유성을 검사하고 두 일치 이벤트를 기록합니다. Stop이나 드라이버 전용 메서드는 호출하지 않습니다. 불일치는 거부로 기록합니다. 나중에 부팅하면 기존 일반 캡처의 PCI/MMIO/PROM 읽기와 진단 파일 쓰기는 수행하지만 잠금 해제/분리/GPU 쓰기/펌웨어 변수 쓰기는 없습니다.

`build-christian-audit-package.ps1`는 **빌드 전용**입니다. 고정 소스 `2bb452f27ccd56f61e591d5a4a6c0431df96403e`를 새 `C:\GPU-Unlock\Builds` 폴더에 받아 기존 LLVM/Python과 현재 시스템 ESP 식별값으로 컴파일/PE 검증하고 Results에 EFI/매니페스트/검증/리비전 ZIP을 만듭니다. USB 쓰기, BootNext, 마운트, EFI 실행이나 재부팅은 없습니다. 컴파일러가 없으면 오류를 보내며 임의 설치하지 않습니다. 설치/부팅 전 빌드 ZIP을 검토용으로 보내세요.

Get-Partition만 보고된 GUID로 모의 처리한 로컬 전체 다운로드/압축해제/컴파일/포장이 통과했습니다. 컴파일러/PE 검증/포장은 실제 실행했으며 장비 시험은 아닙니다. 로컬 EFI는 23552바이트, SHA256 `c7b3807d88ba86a6a3b6ae448b350dd6b829cd49b12fed67747f3e3f522a3358`, AMD64, import/IAT/delay import 없음, NX/dynamic-base입니다. 초기 깊은 경로 두 사례는 컴파일에 실패했고 짧은 임시 경로가 통과했습니다. 기본 경로를 짧게 유지하며 다른 LLVM 바이너리 차이는 출처로 검토합니다.

실시간 허용과 컨트롤러 해제 동작 검증은 별도입니다. 이는 읽기 전용 식별 감사이며 잠금 해제나 장비 검증된 해제 빌드가 아닙니다. 빌드 안내는 재부팅을 허가하지 않습니다.

## 검토한 빌드와 직접 확인하는 런타임 테스트 (2026-11-01)
Christian의 EFI는 24,064바이트이며 SHA256은
`5db74af86fb1b38385a7868985271d83c155821ba4abdec777bcf698f977ccd0`입니다.
매니페스트의 모든 소스 해시가 검토한 소스와 일치했습니다. AMD64와 EFI
애플리케이션 서브시스템을 별도로 확인했습니다. 반환된 PE 보고서에는
임포트 없음 및 NX/ASLR이 기록되어 있습니다. 컴파일러에 따른 바이너리 차이는
소스 불일치를 의미하지 않습니다.

`research/profile/run-christian-audit.ps1`은 이 해시의 이미지만 FAT32 USB에
복사합니다. 시스템/Windows 파티션과 USB가 아닌 디스크는 거부합니다.
기존 EFI를 백업하고 해시를 확인하며 기존 캡처도 보관합니다. USB 복사 후
해시를 다시 확인합니다. `-Mode Collect`는 기존 캡처를 삭제하지 않고
RTX3090-UNLOCK을 C:\GPU-Unlock\Results의 ZIP으로 만듭니다.
자동 재부팅이나 부팅 변수 변경은 없습니다. 모의 디스크 정보로 복사, 백업,
해시 확인, 수집 및 내부 디스크 거부를 검증했지만 실제 펌웨어 동작의 증거는 아닙니다.

직접 지켜보면서 USB를 한 번만 부팅합니다. 기존 캡처는 PCI/MMIO/PROM을 읽고
파일을 저장하며 새 감사 기능은 로드된 콘솔 코드와 메타데이터만 읽습니다.
Stop 콜백, 리셋, DMA, 잠금 해제 또는 새 GPU 쓰기는 없습니다.
읽기나 펌웨어 실행도 멈출 수 있습니다. 2분 뒤에도 Windows가 시작되지 않으면
전원을 끄고 USB를 제거한 뒤 정상 Windows Boot Manager를 선택합니다.
실패한 실행은 반복하지 말고 캡처와 Windows 자동 시작 여부를 알려 주세요.
복구는 보장되지 않습니다. 확인 대상은 로그의 msi-text-code-match와
msi-graphics-code-match이며 잠금 해제 결과가 아닙니다.
