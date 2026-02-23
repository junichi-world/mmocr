param(
    [string]$EnvName = "mmocr310_gpu",
    [string]$CondaBat = "C:\Users\akama\anaconda3\condabin\conda.bat",
    [string]$VsInstall = "C:\Program Files\Microsoft Visual Studio\18\Community",
    [string]$CudaHome = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9",
    [string]$MmcvBuildDir = "C:\work\mmcv_build_210",
    [switch]$CreateEnv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $false)][string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = (Get-Location).Path
    )

    Write-Host ">> $FilePath $($ArgumentList -join ' ')" -ForegroundColor Cyan
    $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -ne 0) {
        throw "Command failed with exit code $($p.ExitCode): $FilePath $($ArgumentList -join ' ')"
    }
}

function Assert-Path {
    param([string]$PathValue, [string]$Name)
    if (-not (Test-Path $PathValue)) {
        throw "$Name not found: $PathValue"
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$VcVars64 = Join-Path $VsInstall "VC\Auxiliary\Build\vcvars64.bat"
$CondaRoot = Split-Path (Split-Path $CondaBat -Parent) -Parent
$EnvRoot = Join-Path $CondaRoot ("envs\" + $EnvName)
$EnvPython = Join-Path $EnvRoot "python.exe"
$EnvScripts = Join-Path $EnvRoot "Scripts"

Assert-Path $CondaBat "Conda"
Assert-Path $VcVars64 "vcvars64.bat"
Assert-Path $CudaHome "CUDA_HOME"
Assert-Path (Join-Path $CudaHome "bin\nvcc.exe") "nvcc.exe"
Assert-Path (Join-Path $RepoRoot "setup.py") "MMOCR repo root"

if ($CreateEnv) {
    Run-Checked -FilePath $CondaBat -ArgumentList @("create", "-y", "-n", $EnvName, "python=3.10")
}
Assert-Path $EnvPython "Conda env python.exe"

$CondaRun = @("run", "-n", $EnvName, "python", "-m", "pip")

# 1) PyTorch cu128 stack (supports RTX 50xx / sm_120)
Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @("install", "-U", "pip", "setuptools", "wheel"))
Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @(
    "install", "--force-reinstall",
    "torch==2.7.0", "torchvision==0.22.0", "torchaudio==2.7.0",
    "--index-url", "https://download.pytorch.org/whl/cu128"
))

# 2) OpenMMLab runtime deps (MMOCR 1.0.1 compatible)
Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @(
    "install", "--upgrade", "ninja", "numpy==1.26.4",
    "mmengine==0.10.5", "mmdet==3.3.0"
))
Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @("install", "-r", "requirements\runtime.txt")) -WorkingDirectory $RepoRoot
Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @("install", "-e", ".", "--no-deps")) -WorkingDirectory $RepoRoot

# 3) Rebuild mmcv 2.1.0 from source against torch 2.7.0+cu128
if (Test-Path $MmcvBuildDir) {
    Write-Host "Using existing mmcv source dir: $MmcvBuildDir" -ForegroundColor Yellow
} else {
    Run-Checked -FilePath "git.exe" -ArgumentList @(
        "clone", "--depth", "1", "--branch", "v2.1.0",
        "https://github.com/open-mmlab/mmcv.git", $MmcvBuildDir
    )
}

Run-Checked -FilePath $CondaBat -ArgumentList ($CondaRun + @("uninstall", "-y", "mmcv"))

$cmdLines = @(
    'set "PATH=' + $EnvScripts + ';'
        + (Join-Path $VsInstall 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin')
        + ';%PATH%"',
    '"' + $VcVars64 + '"',
    'set "DISTUTILS_USE_SDK=1"',
    'set "MSSdk=1"',
    'set "CC=cl.exe"',
    'set "CXX=cl.exe"',
    'set "TORCH_DONT_CHECK_COMPILER_ABI=1"',
    'set "CUDA_HOME=' + $CudaHome + '"',
    'set "MMCV_WITH_OPS=1"',
    'set "FORCE_CUDA=1"',
    'set "TORCH_CUDA_ARCH_LIST=12.0"',
    'set "MMCV_CUDA_ARGS=-allow-unsupported-compiler"',
    '"' + $EnvPython + '" setup.py develop'
)
$cmdChain = [string]::Join(" && ", $cmdLines)
Run-Checked -FilePath "cmd.exe" -ArgumentList @("/c", $cmdChain) -WorkingDirectory $MmcvBuildDir

# 4) Verification
Run-Checked -FilePath $EnvPython -ArgumentList @(
    "-c",
    "import torch, mmcv, mmengine, mmdet, mmocr; from mmcv.ops import nms; " +
    "print('torch', torch.__version__, 'cuda', torch.version.cuda, 'avail', torch.cuda.is_available()); " +
    "print('arch', torch.cuda.get_arch_list()); " +
    "print('mmcv', mmcv.__version__, 'ops', callable(nms)); " +
    "print('mmengine', mmengine.__version__, 'mmdet', mmdet.__version__, 'mmocr', mmocr.__version__)"
)

Write-Host ""
Write-Host "Done. GPU environment is rebuilt for RTX 50xx (sm_120)." -ForegroundColor Green
Write-Host "Test command:" -ForegroundColor Green
Write-Host "  conda run -n $EnvName python tools/infer.py demo/demo_text_ocr.jpg --det DBNet --rec CRNN --device cuda --print-result"
