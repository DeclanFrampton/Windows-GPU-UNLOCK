# Windows 호스트 검증

기존 Python3, clang, MSVC/Windows SDK가 있는 환경에서 고정 소스로 실행하세요.

```powershell
powershell -NoProfile -File .\research\pci-decode\test-decode-sync.ps1
```

도구 검색이 실패하면 기존 설치 경로를 -Python, -Clang, -VcVars로 지정하세요.
설치, 영구 PATH 수정 또는 정책 변경은 요청하지 않습니다. 자식 프로세스에서만
컴파일러 환경을 설정하고 기존 공유 core/adapter/capture 및 모든 컴파일된
guard mutation 테스트를 실행합니다. 새 Documents/GPU-Unlock-Decode-Host-*/run/
summary.json을 생성합니다. PR139 병합 소스에서 전체 PASS와21개 mutation 검출을
예상합니다. 네이티브 Windows RAM 모의 테스트이며 EFI ABI/하드웨어, production
통합, 프로필 승인 또는 Windows 복귀 증거가 아닙니다. 필요하면 검토한
summary.json만 보내세요. 관리자가 이미 실행한 테스트를 제보자가 반복할 필요는
없습니다. 도구 누락/실패면 중지하고 개인 정보를 제거한 짧은 오류를 보내세요.
캡처, 펌웨어, USB 준비 또는 재부팅은 없습니다.
