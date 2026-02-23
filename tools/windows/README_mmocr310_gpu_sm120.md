# MMOCR 1.0.1 GPU Rebuild (Python 3.10, RTX 50xx / sm_120)

This repo can run on RTX 50xx laptops, but the stock `mmcv` wheel used by MMOCR 1.0.1 does not support the required PyTorch/CUDA combo on Windows.

This folder provides a reproducible rebuild script that:

- installs `torch==2.7.0+cu128` (supports `sm_120`)
- keeps MMOCR-compatible versions:
  - `mmengine==0.10.5`
  - `mmdet==3.3.0`
  - `mmcv==2.1.0` (built from source with CUDA ops)
- installs this repo as editable `mmocr`

## Prerequisites (Windows)

- Conda (Anaconda/Miniconda)
- Python 3.10 environment (or let the script create one)
- Visual Studio with MSVC C++ build tools (the script defaults to VS 2026 path)
- CUDA Toolkit 12.9 installed (`nvcc` available)
- Git

## Run

From repo root (`C:\work\mmocr_gpu`):

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\rebuild_mmocr310_gpu_sm120.ps1
```

If you want the script to create the conda env:

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\rebuild_mmocr310_gpu_sm120.ps1 -CreateEnv
```

## Custom paths

If your paths differ, override them:

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\rebuild_mmocr310_gpu_sm120.ps1 `
  -CondaBat "C:\Users\YOURNAME\anaconda3\condabin\conda.bat" `
  -VsInstall "C:\Program Files\Microsoft Visual Studio\18\Community" `
  -CudaHome "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9" `
  -EnvName "mmocr310_gpu"
```

## Smoke test

```powershell
conda run -n mmocr310_gpu python tools\infer.py demo\demo_text_ocr.jpg --det DBNet --rec CRNN --device cuda --print-result
```

## Notes

- The script passes `MMCV_CUDA_ARGS=-allow-unsupported-compiler` because CUDA 12.9 may reject newer Visual Studio versions by default.
- A CUDA `12.9` toolkit with a `torch + cu128` build is acceptable here (minor-version mismatch warning is usually non-fatal).
