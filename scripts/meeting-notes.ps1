#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir '..'))

$PythonVersion = if ($env:UV_PYTHON_VERSION) { $env:UV_PYTHON_VERSION } else { '3.12' }
$Variant = if ($env:UV_TORCH_VARIANT) { $env:UV_TORCH_VARIANT } else { 'auto' }
$TorchSpec = if ($env:UV_TORCH_SPEC) { $env:UV_TORCH_SPEC } else { 'torch==2.5.1' }
$TorchaudioSpec = if ($env:UV_TORCHAUDIO_SPEC) { $env:UV_TORCHAUDIO_SPEC } else { 'torchaudio==2.5.1' }

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Error "uv is required. Install via 'pipx install uv' or 'pip install uv'."
  exit 1
}

Write-Host "Ensuring dependencies are in sync (first run may download models)…"
try {
  uv sync --project $ProjectRoot --python $PythonVersion --frozen *> $null
} catch {
  uv sync --project $ProjectRoot --python $PythonVersion
}

function Ensure-TorchStack {
  param()
  $desired = $Variant

  if ($desired -eq 'auto') {
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
      $desired = 'cu124'
    } else {
      $desired = 'cpu'
    }
    Write-Host "Auto-selecting Torch variant: $desired"
  }

  if ($desired -eq 'none') { return }

  $isMac = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
  $indexArgs = @()
  switch ($desired) {
    'cpu' {
      if (-not $isMac) { $indexArgs = @('--index-url','https://download.pytorch.org/whl/cpu') }
    }
    'cu124' { $indexArgs = @('--index-url','https://download.pytorch.org/whl/cu124') }
    default { throw "Unknown UV_TORCH_VARIANT='$desired'. Supported: auto, cpu, cu124, none." }
  }

  Write-Host "Installing Torch stack ($desired)…"
  if ($indexArgs.Length -gt 0) {
    uv run --project $ProjectRoot --python $PythonVersion `
      pip install --no-deps --upgrade $TorchSpec $TorchaudioSpec @indexArgs
  } else {
    uv run --project $ProjectRoot --python $PythonVersion `
      pip install --no-deps --upgrade $TorchSpec $TorchaudioSpec
  }
}

Ensure-TorchStack

if ($env:HF_TOKEN) {
  Write-Host "HF_TOKEN detected – diarisation will be enabled."
} else {
  Write-Host "HF_TOKEN not set – transcript will use a single default speaker (export HF_TOKEN to enable diarisation)."
}

uv run --project $ProjectRoot --python $PythonVersion meeting-notes @args

