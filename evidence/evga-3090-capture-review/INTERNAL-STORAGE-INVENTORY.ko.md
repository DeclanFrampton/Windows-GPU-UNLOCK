# EVGA 내부 부팅: 읽기 전용 저장소 조사

[English](INTERNAL-STORAGE-INVENTORY.en.md) | [한국어](INTERNAL-STORAGE-INVENTORY.ko.md)

검증된 EVGA 프로필은 현재 USB를 사용합니다. 별도의 내부 런처는 다른 시스템용이므로 그대로 사용할 수 없습니다. EVGA 내부 경로를 설계하기 전에 이 조사는 부팅 설정 변경, 파티션 마운트 또는 포맷, 디스크 쓰기 없이 저장소 구성과 기존 전용 EFI 파티션 후보를 식별합니다.

업데이트한 브랜치의 저장소 루트에서 실행합니다.

```powershell
powershell -NoProfile -File ./research/profile/inspect-internal-storage.ps1
```

JSON에는 디스크 번호, 버스 유형, 파티션 크기/유형, 드라이브 문자 및 파일 시스템이 포함됩니다. 디스크 일련번호와 파티션 GUID는 제외됩니다. 공유하기 전에 내용을 확인하고 출력 또는 오류를 보내 주세요. `candidate_dedicated_esp`는 시스템 또는 부팅 파티션이 아니고 드라이브 문자가 있는 1 GiB 이상의 비 USB FAT32 GPT EFI 파티션 후보일 뿐입니다. 파티션이 사용되지 않거나 쓰기에 안전하거나 펌웨어에서 접근 가능하거나 EVGA 프로필에 적합하다는 보장은 아닙니다. 드라이브 문자가 없는 EFI 파티션은 후보로 식별되지 않습니다. 후보가 없어도 파티션 변경을 승인하는 것은 아닙니다.

로컬 검증: 모의 시스템/전용/USB 사례와 연구용 시스템의 읽기 전용 조사를 통과했습니다. 이 단계에서는 실제 EVGA 내부 부팅 구현이나 설치를 하지 않습니다.
