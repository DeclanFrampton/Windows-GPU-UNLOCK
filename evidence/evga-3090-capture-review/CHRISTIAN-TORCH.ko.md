# 잠금 해제 전 PyTorch 기준 성능

[English](CHRISTIAN-TORCH.en.md)

준비 ZIP에서 Python/NVIDIA 도구는 있고 nvcc/CUDA_PATH/cuBLAS 툴킷과 torch는 없었습니다. 새 스크립트는 `C:\GPU-Unlock\BenchmarkEnv-v1`에만 환경을 만들고 공식 PyTorch CUDA12.6 인덱스에서 `torch==2.14.1+cu126`을 설치합니다. [공식 설치 경로](https://pytorch.org/get-started/previous-versions/)를 사용하며 시스템 CUDA/드라이버/Python은 변경하지 않습니다. 수 GB 다운로드와 여유 공간이 필요합니다.

`run-christian-torch-baseline.ps1`는 정확한 버전/CUDA/RTX3090 이름을 확인하고 128x128 곱을 CPU float64와 비교한 뒤 4096x4096 GEMM 네 모드를 CUDA 이벤트로 측정합니다. 모드별 준비 10회, 10표본 시험 세 번이며 고정 시드, 플래그, 출력 정밀도, 시험값 및 패키지/소스 출처를 ZIP에 저장합니다. 결과는 `C:\GPU-Unlock\Results`에 있습니다. FP16/BF16 출력은 기존 cuBLAS FP32 출력과 달라 이 프로토콜의 전후 결과끼리만 비교해야 합니다. 작은 참조 및 유한값 검사는 포괄적 수치 검증이 아닙니다.

실제 GPU 부하이므로 작업을 저장하고 GPU 앱을 닫으세요. 튜닝, 클록/전력 제한 변경, 펌웨어 쓰기, EFI나 재부팅은 없습니다. 오류/멈춤 시 부분 파일을 보존하고 보고하며 자동 재시험/환경 삭제는 하지 않습니다. ZIP 또는 오류 스크린샷과 측정 전에 잠금 해제 EFI 실행 여부를 보내세요. 현재 상태 측정이며 잠금 상태 자체를 입증하지 않습니다.

전달 전 검증은 PowerShell 구문, 내장 Python AST 컴파일과 TFLOPS 계산입니다. 고정 환경에서 로컬/기여자 GPU 실행은 아직 없으며 첫 실행은 실제 검증입니다. 설치/참조/API 실패는 성능 결과가 아닌 실패입니다.
