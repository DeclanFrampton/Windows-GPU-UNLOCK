# 잠금 해제 전 PyTorch 기준 성능

## 반환 기준 성능과 큰 행렬 검사

고정 러너가 완료되었습니다. 소스 해시와 영수증이 일치하고 유한 시험값의 중앙값 재계산이 통과했습니다. FP32 23.489277, FP16 출력 67.294447, BF16 출력 68.373777, TF32 33.846756 TFLOPS입니다. [요약](christian-torch-baseline.json). 현재 성능만 기록하며 이전 잠금 해제 실행 여부 확인은 대기 중입니다.

다음 `check-christian-large-gemm.ps1`는 설치 없이 기존 환경을 사용합니다. 4096x4096의 모드별 고정 출력 여덟 값을 양자화 입력 행/열의 CPU float64 내적과 비교하고 전체 유한값을 검사합니다. 128x128 참조와 측정 크기의 간격 일부를 확인하지만 32표본은 포괄 검증이 아닙니다. 고정 Results 경로에 러너와 JSON/ZIP을 저장합니다. 시간 비교, 튜닝, 펌웨어 쓰기나 재부팅은 없습니다. passed=false여도 ZIP을 보내세요. 실행 오류는 부분 파일을 보존하고 오류를 보내며 자동 반복하지 않습니다. PowerShell 구문과 내장 Python 컴파일은 통과했으며 실제 GPU 결과는 대기 중입니다.

[English](CHRISTIAN-TORCH.en.md)

준비 ZIP에서 Python/NVIDIA 도구는 있고 nvcc/CUDA_PATH/cuBLAS 툴킷과 torch는 없었습니다. 새 스크립트는 `C:\GPU-Unlock\BenchmarkEnv-v1`에만 환경을 만들고 공식 PyTorch CUDA12.6 인덱스에서 `torch==2.14.1+cu126`을 설치합니다. [공식 설치 경로](https://pytorch.org/get-started/previous-versions/)를 사용하며 시스템 CUDA/드라이버/Python은 변경하지 않습니다. 수 GB 다운로드와 여유 공간이 필요합니다.

`run-christian-torch-baseline.ps1`는 정확한 버전/CUDA/RTX3090 이름을 확인하고 128x128 곱을 CPU float64와 비교한 뒤 4096x4096 GEMM 네 모드를 CUDA 이벤트로 측정합니다. 모드별 준비 10회, 10표본 시험 세 번이며 고정 시드, 플래그, 출력 정밀도, 시험값 및 패키지/소스 출처를 ZIP에 저장합니다. 결과는 `C:\GPU-Unlock\Results`에 있습니다. FP16/BF16 출력은 기존 cuBLAS FP32 출력과 달라 이 프로토콜의 전후 결과끼리만 비교해야 합니다. 작은 참조 및 유한값 검사는 포괄적 수치 검증이 아닙니다.

실제 GPU 부하이므로 작업을 저장하고 GPU 앱을 닫으세요. 튜닝, 클록/전력 제한 변경, 펌웨어 쓰기, EFI나 재부팅은 없습니다. 오류/멈춤 시 부분 파일을 보존하고 보고하며 자동 재시험/환경 삭제는 하지 않습니다. ZIP 또는 오류 스크린샷과 측정 전에 잠금 해제 EFI 실행 여부를 보내세요. 현재 상태 측정이며 잠금 상태 자체를 입증하지 않습니다.

전달 전 검증은 PowerShell 구문, 내장 Python AST 컴파일과 TFLOPS 계산입니다. 고정 환경에서 로컬/기여자 GPU 실행은 아직 없으며 첫 실행은 실제 검증입니다. 설치/참조/API 실패는 성능 결과가 아닌 실패입니다.
