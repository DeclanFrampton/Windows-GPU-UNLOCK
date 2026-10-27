# RTX4070Ti unlock 연구 로드맵

[English](ROADMAP.en.md) | 한국어

실제21차 기준 **15/26개 이정표=체크리스트58%**(반올림)입니다. 같은 수로 세지만 난이도는
같지 않습니다. 성공 확률·남은 시간·하드웨어 unlock 비율이 아니며 unlock은 미입증입니다.

| 단계 | 완료/전체 | 완료율 | 증거와 남은 작업 |
| --- | --- | --- | --- |
| 기준 상태 | 4/4 | 100% | 인벤토리, 기본 연산, 소유권 지도, 검증 보관 |
| 펌웨어 소유권 해제 | 4/4 | 100% | 텍스트/GOP, EDID, 직접 자식, 부모 Stop 입증 |
| 레지스터/복귀 | 3/3 | 100% | 제한적 디코딩/읽기, 시간차 배치 일치, decode-off/직접 Windows 복귀 |
| ROM/FWSEC 자료 | 3/4 | 75% | RAM ROM, 실제 헤더, 전체 PROM 캡처. FWSEC 위치/범위/해시 있음; 실행 준비 검증 미완료 |
| 정확한 PC 허용 조건 | 1/4 | 25% | 레지스터 수집. SS1, VGA/배치 설명과 정당화된 PC별 정책 필요 |
| 보호된 unlock 트랜잭션 | 0/4 | 0% | PC별 설계, 오프라인 검증, 승인 실행, 독립 상태 재확인 필요 |
| Windows unlock 입증 | 0/3 | 0% | unlock 후 드라이버, 통제 연산 비교, 완전 종료 부팅/복구 반복 필요 |

100% 행은 이 컴퓨터에서 좁게 정의한 항목의 완료이며 복구 보장이나 일반적 플랫폼 안전성을 뜻하지 않습니다.

## 이정표

- [x] GPU/플랫폼 정확한 인벤토리
- [x] 기본 연산 기준
- [x] 펌웨어 소유 관계 지도
- [x] 해시 검증 자료 보관
- [x] 텍스트/GOP 소비자 통합 중지
- [x] EDID 소비자 중지
- [x] 직접 소유자 자식 중지
- [x] 직접 부모 중지
- [x] 제한적 디코딩과 실제 레지스터 캡처
- [x] 시간차 레지스터 비교
- [x] 검증된 decode-off/직접 Windows 복귀
- [x] 펌웨어 RAM ROM 및 제한된 PCIR 체인 분석
- [x] 실제 PROM 헤더 관찰
- [x] 전체 실제 PROM 전송/파일 검증
- [ ] 제안된 실행 정책에 대한 FWSEC 자료 검증(구조/해시는 있으나 인증·준비성 미입증)
- [x] 해제 후 선행 레지스터 표본
- [ ] SS1 상태 설명·정당화
- [ ] VGA_BASE/메모리 배치 차이 설명
- [ ] 참조를 무조건 옮기지 않고 정확한 PC 허용 정책 검증
- [ ] PC별 트랜잭션/실패 경계 설계
- [ ] 필요한 자산/mock을 포함한 오프라인 트랜잭션 검증
- [ ] 제한된 실제 트랜잭션 명시적 승인·실행
- [ ] 의도한 unlock 상태 전환 독립 검증
- [ ] unlock 후 Windows 드라이버 초기화 검증
- [ ] 상태 증거와 통제된 기본/unlock 후 작업 비교
- [ ] 완전 종료 부팅 및 복구 반복 검증

최신 증거: [21차 전체 PROM/FWSEC](AD104-TWENTY-FIRST-RESULT.ko.md).
다음: [22차 관찰 전용 EFI 파서 검사](AD104-TWENTY-SECOND-BOOT.ko.md).
참조 PROM 해시와 descriptor 두 오프셋, SS1/VGA_BASE/BAR 차이가 남아 실행을 막을 수 있습니다.
반복 캡처나 구조 일치만으로 허용 조건·unlock 완료로 세지 않습니다.

[Test22 result / 테스트22 결과](AD104-TWENTY-SECOND-RESULT.ko.md): EFI RAM audit passed; checklist remains 15/26 (58%).

[Test23 passed / 테스트23 통과](AD104-TWENTY-THIRD-RESULT.ko.md). [Next: test24 / 다음: 테스트24](AD104-TWENTY-FOURTH-BOOT.ko.md), sampled-version signature installation in RAM; no new GPU access or execution. Checklist remains15/26(58%).
