# 공유 ESP GPU 미사용 부팅 인계 시험

[English](SHARED-ESP-AUDIT.en.md) | [한국어](SHARED-ESP-AUDIT.ko.md)

이 새로운 시험 EFI는 Windows 전용 공유 ESP 설계를 위한 빌드 전용 후보입니다. 로드된 자체 장치가 고정된 Windows ESP GPT 장치 경로를 가진 유일한 파일 시스템 핸들인지 확인하고 USB 경로 또는 중복 일치를 거부합니다. 그 후 같은 장치의 기존 `\EFI\Microsoft\Boot\bootmgfw.efi`를 로드하고 로드된 이미지 장치를 검사한 뒤 시작합니다. GPU 드라이버 열거/해제, GPU 레지스터 접근, PCI 설정 변경, 잠금 해제, 파일 또는 펌웨어 변수 쓰기, 부팅 순서 변경은 수행하지 않습니다. 해당 실행은 Windows를 직접 시작하며 기존 Limine 항목을 변경하지 않습니다.

이 EFI는 **ESP에 복사하거나 부팅 항목으로 등록하거나 실제 하드웨어에서 실행하지 않았습니다**. 검토된 배포 및 복구 절차도 아직 없습니다. 실행하려면 별도로 안전하게 준비한 EFI 파일과 Windows 및 Limine을 방해하지 않는 선택 방법이 필요합니다. 동일 볼륨 검사는 USB에서 EFI를 부팅하면 거부하므로 USB 부팅만으로 이 시험을 수행할 수 없습니다. 펌웨어가 이미지 로드 또는 Windows 인계 중 거부하거나 멈출 수 있으며 펌웨어 부팅 선택 또는 전원 종료가 필요할 수 있고 복구는 입증되지 않았습니다. 스테이징 및 복구 경로를 검토하기 전에는 실제 ESP에 배포하지 마세요.

정확한 Windows ESP GUID로 로컬 빌드합니다. 컴파일러 경로는 다를 수 있습니다.

```powershell
./research/profile/build-shared-esp-audit.ps1 -WindowsEspGuid "c36c3e86-02aa-4f76-af1b-96e327f9d1c1"
./research/profile/test-shared-esp-audit.ps1
```

로컬 빌드 경로는 `internal-boot/boot/build/shared-esp-audit/AUDIT.EFI`, 크기 4,608바이트, SHA-256 `5490224b49b8a4680f82a453020da47cbfa19775f2c835e15ba1fa98b60fec5d`입니다. 다른 도구체인은 해시가 다를 수 있습니다. PE 검증을 통과했습니다. 모의 UEFI 서비스로 올바른/다른/중복/USB/누락 파티션 핸들, 올바른 Windows 경로와 인계, 잘못된 로드 이미지 장치, 로드 실패 및 중복 거부를 검사했습니다. 이는 호스트 시험이며 실제 UEFI 동작 또는 성공적인 잠금 해제의 근거가 아닙니다.
