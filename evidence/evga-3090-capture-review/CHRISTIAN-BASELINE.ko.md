# Christian Windows 기준 정보 검사

## 빌드 입력 확인 — 2026-11-01

Declan은 Christian이 잠금 해제 EFI를 실행한 적 없다고 확인했습니다. 이 보고를 바탕으로 벤치마크를 해제 전 기준으로 취급하며 독립 증명은 아닙니다. 반환 부팅 정보는 ESP `3be74736-e119-47da-851a-9b1dde4d7037`, 내부 NVMe/FAT32, 읽기 오류 없는 Secure Boot=false와 Windows 로더 SHA256 `3f8a4cbbc97b89836df92c4895236be1fac4a127665420d90509e897a7298511`입니다.

다음 `test-christian-build-preflight.ps1`는 저장된 캡처와 보고서를 이 MSI 입력에 대조하고 ZIP 하나를 만듭니다. 벤치마크 반복이나 실제 펌웨어 조회/변경은 없습니다. 실제 반환 파일을 사용한 저장 입력 일치 검사가 PS7/5.1에서 통과했습니다. 통과는 드라이버 해제 검증이나 잠금 해제 자격이 아닙니다. 실행 상태와 유효한 컨트롤러 제거 콜백은 별도 검증이 필요합니다.

## 반환 결과 — 2026-11-01

기여자 ZIP은 ASUS PRIME H510M-K R2.0, AMI BIOS 0802, RTX3090 서브시스템 38811462, 드라이버 596.49와 24576MiB를 보고합니다. NVIDIA 조회가 성공했고 두 진단 해시는 이전 캡처와 일치합니다. P0, 350W 제한과 최대 SM/메모리 2130/9751MHz는 관찰값이며 권장 설정이나 성능 증거가 아닙니다. GPU 부하나 잠금 해제는 실행하지 않았습니다.

다음 `test-christian-benchmark-readiness.ps1`는 기존 nvcc/Python/NVIDIA 명령과 CUDA 헤더/라이브러리 및 Python의 torch 패키지 발견 여부를 검사하고 `C:\GPU-Unlock\Results`에 ZIP을 만듭니다. torch를 불러오거나 GPU 부하를 실행하지 않습니다. 도구 부재도 유효한 결과이며 설치 요청이 아닙니다. 드라이버 검토 중 잠금 해제 전 벤치마크 경로를 선택하기 위한 검사이며 Stop 경로를 검증하지 않습니다. PS7/5.1의 도구 부재/존재 모의 검사가 통과했습니다.

[English](CHRISTIAN-BASELINE.en.md)

`research/profile/collect-christian-baseline.ps1`를 실행합니다. 기본 캡처 위치는 `C:\GPU-Unlock\Captures`, 고유 출력 폴더/ZIP은 `C:\GPU-Unlock\Results` 아래입니다. 표시된 ZIP을 보내세요. 관리자 권한이나 재부팅은 필요하지 않습니다.

Windows 빌드/부팅 시각, 보드 제품, BIOS 버전, GPU 드라이버/PCI 식별 및 제한된 NVIDIA 조회를 읽습니다. 원시 진단을 복사하지 않고 두 파일 해시를 기록합니다. 일련번호, 전체 PNP 인스턴스와 원시 펌웨어 덤프는 제외합니다. NVIDIA 조회 실패는 실패로 기록합니다. GPU 부하, 벤치마크, 설정 변경, 펌웨어 쓰기, EFI 실행이나 잠금 해제를 하지 않습니다. 현재 구성 기준 정보이며 성능 기준이나 Stop 경로 검증은 아닙니다.

PowerShell 7과 5.1의 모의 검사에서 ZIP 생성, NVIDIA 조회 인자, 개인정보 제외, 캡처 해시 및 잘못된 GPU의 출력 전 거부가 통과했습니다. 실제 조회 성공은 모의 검사로 입증하지 않습니다. 캡처/BIOS 설정을 보존하고 오류 시 오류를 보내세요. EFI를 반복하지 마세요.
