# MSI 실행 시점 감사 빌드 시험

[English](CHRISTIAN-RUNTIME-AUDIT.en.md)

Christian의 저장 입력 검사 아홉 개가 모두 true로 반환되어 기준 수집은 완료되었습니다. 새 `GU_MSI_RUNTIME_AUDIT`는 일반 관찰 프로브의 캡처 후 로드된 DriverBinding/이미지에 대해 MSI 콘솔 두 코드 해시, 버전, Stop RVA와 고유성을 검사하고 두 일치 이벤트를 기록합니다. Stop이나 드라이버 전용 메서드는 호출하지 않습니다. 불일치는 거부로 기록합니다. 나중에 부팅하면 기존 일반 캡처의 PCI/MMIO/PROM 읽기와 진단 파일 쓰기는 수행하지만 잠금 해제/분리/GPU 쓰기/펌웨어 변수 쓰기는 없습니다.

`build-christian-audit-package.ps1`는 **빌드 전용**입니다. 고정 소스 `2bb452f27ccd56f61e591d5a4a6c0431df96403e`를 새 `C:\GPU-Unlock\Builds` 폴더에 받아 기존 LLVM/Python과 현재 시스템 ESP 식별값으로 컴파일/PE 검증하고 Results에 EFI/매니페스트/검증/리비전 ZIP을 만듭니다. USB 쓰기, BootNext, 마운트, EFI 실행이나 재부팅은 없습니다. 컴파일러가 없으면 오류를 보내며 임의 설치하지 않습니다. 설치/부팅 전 빌드 ZIP을 검토용으로 보내세요.

Get-Partition만 보고된 GUID로 모의 처리한 로컬 전체 다운로드/압축해제/컴파일/포장이 통과했습니다. 컴파일러/PE 검증/포장은 실제 실행했으며 장비 시험은 아닙니다. 로컬 EFI는 23552바이트, SHA256 `c7b3807d88ba86a6a3b6ae448b350dd6b829cd49b12fed67747f3e3f522a3358`, AMD64, import/IAT/delay import 없음, NX/dynamic-base입니다. 초기 깊은 경로 두 사례는 컴파일에 실패했고 짧은 임시 경로가 통과했습니다. 기본 경로를 짧게 유지하며 다른 LLVM 바이너리 차이는 출처로 검토합니다.

실시간 허용과 컨트롤러 해제 동작 검증은 별도입니다. 이는 읽기 전용 식별 감사이며 잠금 해제나 장비 검증된 해제 빌드가 아닙니다. 빌드 안내는 재부팅을 허가하지 않습니다.
