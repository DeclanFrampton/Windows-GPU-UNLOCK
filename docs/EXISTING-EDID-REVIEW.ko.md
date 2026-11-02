# 기존 EDID binding 검토 (#144)

```powershell
powershell -NoProfile -File .\tools\test-existing-edid.ps1
```

기존의 완전한 DIAG00/01.TXT 폴더를 선택하세요. 기존 Python3만 사용하며
-Python으로 설치된 정상 실행 파일을 지정할 수 있습니다. IMG/PROM은 불필요합니다.
공유 complete-graph/binding 파서를 재사용하고 CRLF를 지원합니다.
EDID_DISCOVERED와 EDID_ACTIVE의 BY_DRIVER edge를 따로 보고합니다. 숫자는
고유 이미지가 아니라 관측된 edge 수입니다. GUID/version은 펌웨어 메타데이터이며
release fingerprint 또는 검증된 소스 ID가 아닙니다.

#144의 공개 EDID_DISCOVERED owner는 version16,
605ced2c-583b-4171-9311-aa6e146b1a4b, reviewed_mouse_identity_match=false를
예상합니다. 이는 다른 ID로 bound 상태이지 부재가 아닙니다. no-EDID/detach
승인은 false를 유지하며 release 이후 생존 여부를 증명하지 않습니다.
누락/모호한 binding 또는 불완전 캡처는 검토를 중지합니다.

표시된 Documents 폴더의 검토한 edid-review.json만 보내세요. 사용할 수 없거나
차단/실패하면 중지하고 개인 정보를 제거한 짧은 오류를 보내세요. 새 캡처,
GU_NO_EDID_DRIVER gate 완화, 설정 변경 또는 펌웨어 부팅은 하지 마세요.
원본 캡처, 포인터, 이미지와 PROM은 비공개로 유지하세요. 로컬 테스트는 보고된
GUID/version의 합성 소유권 데이터이며 Dell 결과를 독립 검증하거나2560을 승인하지 않습니다.
