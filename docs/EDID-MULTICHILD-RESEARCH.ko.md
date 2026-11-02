# EDID-bound 다중 child runtime 검토

issue114의 반환 JSON은 허용2개 대비 child3개를 확인합니다. 비공개 graph 자체는
독립 검증하지 않았습니다. 모니터 변경이나 추가 부팅은 요청하지 않습니다.

non-aggregate GU_HEADLESS_RESEARCH FullConsumers는 최대4개 child를 순회하며
path/PCI 부모, 동일 EDID owner, secondary child의 GOP/text consumer 부재를
검사합니다. child1개를 요구하는 aggregate fallback은 다른 전처리 분기입니다.
generator/local header는 EDID-bound2개 초과를 명시적으로 거부합니다.
runtime 용량만으로 이 guard를 완화할 수 없습니다.

기존 공통 RAM-only runner에 선택적 --card/--children selector를 추가했습니다.
기본 matrix와 기존 제외 조건은 유지합니다. 기존 host compiler 환경에서 baseline:

```text
python -I research/profile/test_local_release.py --card 0x250410de --children 2 --output <new-output-folder>
```

GA1068개 조합(bus1/2b, PCI command2/3, EDID/no-EDID)이 로컬 통과했습니다.
EDID 각6456개, no-EDID 각4961개 검사입니다. 합성 RAM fixture의 기존2-child
production code 동작이며3-child 검증, vendor firmware 실행, 기여자 하드웨어
증거가 아닙니다. 다음은 같은 harness에서3-child EDID 계약 및 negative mutation
검증입니다. generator/header 확장 제안 전에 필요하며 guard 변경이나 사용자
재실행 요청은 없습니다.
