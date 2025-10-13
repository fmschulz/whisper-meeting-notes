#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
Usage: meeting-notes.ps1 [--tailscale-host HOST | --remote-http URL] [options] <audio-file> [output-file]

Remote execution options:
  --tailscale-host HOST    Copy audio to HOST over Tailscale, run transcription there, and download the notes.
  --tailscale-user USER    SSH user for the remote host (defaults to TAILSCALE_REMOTE_USER if set).
  --tailscale-repo PATH    Path to this repository on the remote host (default: ~/whisper-meeting-notes).
  --tailscale-workdir DIR  Remote working directory (relative to repo or absolute) for per-run artefacts (default: .remote-jobs).
  --remote-http URL        Upload via HTTPS to a public drop server (for laptops without Tailscale).
  --tailscale-keep         Keep the remote artefacts instead of deleting them after download.
  --help, -h               Show this message (pass -- --help for the Python CLI usage).

All other options are passed through to the underlying Python CLI.
"@
}

function Get-AbsolutePath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $expanded = [Environment]::ExpandEnvironmentVariables($Path)
  if ($expanded.StartsWith('~')) {
    $home = [Environment]::GetFolderPath('UserProfile')
    if ($expanded.Length -eq 1) {
      $expanded = $home
    } else {
      $expanded = Join-Path $home $expanded.Substring(2)
    }
  }
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return [System.IO.Path]::GetFullPath($expanded)
  } else {
    $pwd = Get-Location
    return [System.IO.Path]::GetFullPath((Join-Path $pwd.Path $expanded))
  }
}

function Get-ShellQuoted {
  param([Parameter(Mandatory = $true)][string]$Text)
  return "'" + $Text.Replace("'", "'\"'\"'") + "'"
}

function Invoke-TailscaleCommand {
  param(
    [Parameter(Mandatory = $true)][string]$TailscalePath,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Command
  )

  & $TailscalePath 'ssh' $Target 'bash' '-lc' $Command
  if ($LASTEXITCODE -ne 0) {
    throw "tailscale ssh command failed with exit code $LASTEXITCODE."
  }
}

function Send-FileOverTailscale {
  param(
    [Parameter(Mandatory = $true)][string]$TailscalePath,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$RemotePath,
    [Parameter(Mandatory = $true)][string]$LocalPath
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $TailscalePath
  $psi.ArgumentList.Add('ssh')
  $psi.ArgumentList.Add($Target)
  $psi.ArgumentList.Add('bash')
  $psi.ArgumentList.Add('-lc')
  $psi.ArgumentList.Add("cat > $(Get-ShellQuoted $RemotePath)")
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = [System.Diagnostics.Process]::Start($psi)
  try {
    $inputStream = $proc.StandardInput.BaseStream
    $fileStream = [System.IO.File]::OpenRead($LocalPath)
    try {
      $fileStream.CopyTo($inputStream)
    } finally {
      $inputStream.Close()
      $fileStream.Close()
    }
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
      $stderr = $proc.StandardError.ReadToEnd()
      throw "tailscale ssh upload failed with exit code $($proc.ExitCode): $stderr"
    }
  } finally {
    $proc.Dispose()
  }
}

function Receive-FileOverTailscale {
  param(
    [Parameter(Mandatory = $true)][string]$TailscalePath,
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$RemotePath,
    [Parameter(Mandatory = $true)][string]$LocalPath
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $TailscalePath
  $psi.ArgumentList.Add('ssh')
  $psi.ArgumentList.Add($Target)
  $psi.ArgumentList.Add('bash')
  $psi.ArgumentList.Add('-lc')
  $psi.ArgumentList.Add("cat $(Get-ShellQuoted $RemotePath)")
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = [System.Diagnostics.Process]::Start($psi)
  try {
    $outputStream = $proc.StandardOutput.BaseStream
    $directory = Split-Path -Parent $LocalPath
    if ($directory) {
      [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $fileStream = [System.IO.File]::Open($LocalPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
      $outputStream.CopyTo($fileStream)
    } finally {
      $fileStream.Close()
    }
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
      $stderr = $proc.StandardError.ReadToEnd()
      throw "tailscale ssh download failed with exit code $($proc.ExitCode): $stderr"
    }
  } finally {
    $proc.Dispose()
  }
}

function Parse-MeetingArgs {
  param([string[]]$Arguments)

  $optionsWithValue = @('--model', '--batch-size', '--temperature', '--beam-size')
  $positionals = [System.Collections.Generic.List[string]]::new()
  $passthrough = [System.Collections.Generic.List[string]]::new()
  $optionsEnded = $false
  $expectValue = $false
  $pendingOption = $null

  foreach ($current in $Arguments) {
    if ($expectValue) {
      $passthrough.Add($current)
      $expectValue = $false
      $pendingOption = $null
      continue
    }
    if (-not $optionsEnded -and $current -eq '--') {
      $passthrough.Add($current)
      $optionsEnded = $true
      continue
    }
    if (-not $optionsEnded -and $current -like '--*=*') {
      $passthrough.Add($current)
      continue
    }
    if (-not $optionsEnded -and $current -like '--*') {
      $passthrough.Add($current)
      if ($optionsWithValue -contains $current) {
        $expectValue = $true
        $pendingOption = $current
      }
      continue
    }
    if (-not $optionsEnded -and $current.StartsWith('-')) {
      $passthrough.Add($current)
      continue
    }
    $positionals.Add($current)
  }

  if ($expectValue) {
    throw "Missing value for option $pendingOption"
  }

  [pscustomobject]@{
    Audio      = if ($positionals.Count -ge 1) { $positionals[0] } else { $null }
    Output     = if ($positionals.Count -ge 2) { $positionals[1] } else { $null }
    Passthrough = $passthrough.ToArray()
  }
}

function Invoke-RemoteTranscription {
  param(
    [string]$Audio,
    [string]$Output,
    [string[]]$Extras,
    [string]$RemoteHost,
    [string]$RemoteUser,
    [string]$RemoteRepo,
    [string]$RemoteWorkdir,
    [switch]$KeepRemote,
    [string]$TailscalePath
  )

  if (-not $Audio) {
    throw "Audio file is required when using --tailscale-host."
  }
  if (-not (Test-Path -LiteralPath $TailscalePath)) {
    throw "tailscale CLI not found (set TAILSCALE_BIN if it lives elsewhere)."
  }

  $audioPath = Get-AbsolutePath $Audio
  if (-not (Test-Path -LiteralPath $audioPath)) {
    throw "Audio file not found: $Audio"
  }

  $targetOutput = $Output
  if (-not $targetOutput) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $targetOutput = Join-Path (Split-Path -Parent $audioPath) ("{0}-notes-{1}.md" -f ([System.IO.Path]::GetFileNameWithoutExtension($audioPath)), $timestamp)
  }
  $localOutput = Get-AbsolutePath $targetOutput
  $localDir = Split-Path -Parent $localOutput
  if ($localDir) {
    [System.IO.Directory]::CreateDirectory($localDir) | Out-Null
  }

  if (-not $RemoteHost) {
    throw "--tailscale-host requires a hostname or MagicDNS name."
  }
  $remoteTarget = if ($RemoteUser) { "$RemoteUser@$RemoteHost" } else { $RemoteHost }
  $remoteRepoPath = if ([string]::IsNullOrWhiteSpace($RemoteRepo)) { '~/whisper-meeting-notes' } else { $RemoteRepo }
  $workBase = if ($RemoteWorkdir.StartsWith('/') -or $RemoteWorkdir.StartsWith('~')) {
    $RemoteWorkdir.TrimEnd('/')
  } else {
    "$($remoteRepoPath.TrimEnd('/'))/$($RemoteWorkdir.TrimStart('/'))"
  }
  $jobId = "{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), (Get-Random -Maximum 100000)
  $remoteJobDir = "$workBase/$jobId"
  $remoteAudioPath = "$remoteJobDir/$([System.IO.Path]::GetFileName($audioPath))"
  $remoteOutputPath = "$remoteJobDir/$([System.IO.Path]::GetFileName($localOutput))"

  Write-Host "Preparing remote workspace on $remoteTarget…"
  Invoke-TailscaleCommand -TailscalePath $TailscalePath -Target $remoteTarget -Command ("mkdir -p {0}" -f (Get-ShellQuoted $remoteJobDir))

  Write-Host "Uploading $(Split-Path -Leaf $audioPath) to $remoteTarget…"
  Send-FileOverTailscale -TailscalePath $TailscalePath -Target $remoteTarget -RemotePath $remoteAudioPath -LocalPath $audioPath

  $envVars = @('HF_TOKEN','UV_TORCH_VARIANT','UV_PYTHON_VERSION','UV_TORCH_SPEC','UV_TORCHAUDIO_SPEC','CUDA_VISIBLE_DEVICES','CUDNN_COMPAT_DIR')
  $assignments = @()
  foreach ($name in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if (-not [string]::IsNullOrEmpty($value)) {
      $assignments += "$name=$(Get-ShellQuoted $value)"
    }
  }

  $remoteCommand = "cd $(Get-ShellQuoted $remoteRepoPath) && "
  if ($assignments.Count -gt 0) {
    $remoteCommand += ($assignments -join ' ') + ' '
  }
  $remoteCommand += "./scripts/meeting-notes.sh $(Get-ShellQuoted $remoteAudioPath) $(Get-ShellQuoted $remoteOutputPath)"
  foreach ($extra in $Extras) {
    $remoteCommand += ' ' + (Get-ShellQuoted $extra)
  }

  Write-Host "Starting transcription on $remoteTarget…"
  Invoke-TailscaleCommand -TailscalePath $TailscalePath -Target $remoteTarget -Command $remoteCommand

  Write-Host "Downloading notes to $localOutput…"
  Receive-FileOverTailscale -TailscalePath $TailscalePath -Target $remoteTarget -RemotePath $remoteOutputPath -LocalPath $localOutput

  if ($KeepRemote) {
    Write-Host "Remote artefacts kept at $remoteTarget:$remoteJobDir"
  } else {
    Invoke-TailscaleCommand -TailscalePath $TailscalePath -Target $remoteTarget -Command ("rm -rf {0}" -f (Get-ShellQuoted $remoteJobDir))
  }

  Write-Host "Notes saved to $localOutput"
}

function Invoke-HttpRemoteTranscription {
  param(
    [Parameter(Mandatory = $true)][string]$Endpoint,
    [Parameter(Mandatory = $true)][string]$Audio,
    [string]$Output,
    [string[]]$Extras,
    [int]$TimeoutSeconds = 600
  )

  if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) {
    throw "Invoke-RestMethod is required for HTTP uploads."
  }

  $audioPath = Get-AbsolutePath $Audio
  if (-not (Test-Path -LiteralPath $audioPath)) {
    throw "Audio file not found: $Audio"
  }

  $audioInfo = Get-Item -LiteralPath $audioPath
  $audioStem = [System.IO.Path]::GetFileNameWithoutExtension($audioInfo.Name)

  $targetOutput = $Output
  if (-not $targetOutput) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $targetOutput = Join-Path (Get-Location) "remote-results/${timestamp}-$audioStem.md"
  }
  $localOutput = Get-AbsolutePath $targetOutput
  $localDir = Split-Path -Parent $localOutput
  if ($localDir) {
    [System.IO.Directory]::CreateDirectory($localDir) | Out-Null
  }

  $uploadUrl = ("{0}/upload" -f $Endpoint.TrimEnd('/'))
  Write-Host "Uploading $($audioInfo.Name) to $uploadUrl…"

  $form = @{
    file        = $audioInfo
    output_name = [System.IO.Path]::GetFileName($localOutput)
  }
  if ($Extras -and $Extras.Length -gt 0) {
    $form.options = ($Extras | ConvertTo-Json -Compress)
  }
  try {
    $response = Invoke-RestMethod -Uri $uploadUrl -Method Post -Form $form -TimeoutSec $TimeoutSeconds
  } catch {
    throw "Upload failed: $($_.Exception.Message)"
  }

  if (-not $response.job_id) {
    throw "Unexpected response from server: $($response | Out-String)"
  }

  $jobId = $response.job_id
  $statusUrl = $response.status_url
  $resultUrl = $response.result_url

  Write-Host "Job $jobId queued. Polling status…"
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

  while ($true) {
    try {
      $status = Invoke-RestMethod -Uri $statusUrl -Method Get -TimeoutSec 60
    } catch {
      throw "Failed to fetch job status: $($_.Exception.Message)"
    }

    switch ($status.status) {
      'completed' {
        Write-Host "Transcription complete. Downloading notes…"
        try {
          Invoke-WebRequest -Uri $resultUrl -OutFile $localOutput -TimeoutSec 120
        } catch {
          throw "Failed to download notes: $($_.Exception.Message)"
        }
        Write-Host "Notes saved to $localOutput"
        return
      }
      'error' {
        $message = if ($status.error) { $status.error } else { 'unknown error' }
        throw "Remote transcription failed: $message"
      }
      'processing' { Write-Host "  … job is processing." }
      'pending'    { Write-Host "  … job pending in queue." }
      default      { Write-Host "  … job status: $($status.status)" }
    }

    if ($stopwatch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
      throw "Timed out waiting for remote transcription after $TimeoutSeconds seconds."
    }

    Start-Sleep -Seconds 5
  }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir '..'))

$PythonVersion = if ($env:UV_PYTHON_VERSION) { $env:UV_PYTHON_VERSION } else { '3.12' }
$Variant = if ($env:UV_TORCH_VARIANT) { $env:UV_TORCH_VARIANT } else { 'auto' }
$TorchSpec = if ($env:UV_TORCH_SPEC) { $env:UV_TORCH_SPEC } else { 'torch==2.5.1' }
$TorchaudioSpec = if ($env:UV_TORCHAUDIO_SPEC) { $env:UV_TORCHAUDIO_SPEC } else { 'torchaudio==2.5.1' }
$TailscaleBin = if ($env:TAILSCALE_BIN) { $env:TAILSCALE_BIN } else { 'tailscale' }
$TailscaleUser = if ($env:TAILSCALE_REMOTE_USER) { $env:TAILSCALE_REMOTE_USER } else { $null }
$RemoteRepoDefault = if ($env:TAILSCALE_REMOTE_REPO) { $env:TAILSCALE_REMOTE_REPO } else { '~/whisper-meeting-notes' }
$RemoteWorkdirDefault = if ($env:TAILSCALE_REMOTE_WORKDIR) { $env:TAILSCALE_REMOTE_WORKDIR } else { '.remote-jobs' }
$KeepRemoteDefault = if ($env:TAILSCALE_KEEP_REMOTE_JOB) { $true } else { $false }
$RemoteHttpDefault = if ($env:REMOTE_HTTP_ENDPOINT) { $env:REMOTE_HTTP_ENDPOINT } else { $null }
$HttpTimeout = if ($env:HTTP_TIMEOUT) { [int]$env:HTTP_TIMEOUT } else { 600 }

$tailscaleHost = $null
$tailscaleUser = $TailscaleUser
$remoteRepo = $RemoteRepoDefault
$remoteWorkdir = $RemoteWorkdirDefault
$keepRemote = $KeepRemoteDefault
$remoteHttp = $RemoteHttpDefault

$positionalArgs = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $args.Length; $i++) {
  switch ($args[$i]) {
    '--tailscale-host' {
      if ($i + 1 -ge $args.Length) { throw "--tailscale-host expects a value." }
      $tailscaleHost = $args[$i + 1]
      $i++
    }
    '--tailscale-user' {
      if ($i + 1 -ge $args.Length) { throw "--tailscale-user expects a value." }
      $tailscaleUser = $args[$i + 1]
      $i++
    }
    '--tailscale-repo' {
      if ($i + 1 -ge $args.Length) { throw "--tailscale-repo expects a value." }
      $remoteRepo = $args[$i + 1]
      $i++
    }
    '--tailscale-workdir' {
      if ($i + 1 -ge $args.Length) { throw "--tailscale-workdir expects a value." }
      $remoteWorkdir = $args[$i + 1]
      $i++
    }
    '--tailscale-keep' {
      $keepRemote = $true
    }
    '--remote-http' {
      if ($i + 1 -ge $args.Length) { throw "--remote-http expects a value." }
      $remoteHttp = $args[$i + 1]
      $i++
    }
    '--help'
    '-h' {
      Show-Usage
      exit 0
    }
    '--' {
      for ($j = $i + 1; $j -lt $args.Length; $j++) {
        $positionalArgs.Add($args[$j])
      }
      break 2
    }
    default {
      $positionalArgs.Add($args[$i])
    }
  }
}

if ($tailscaleHost -and $remoteHttp) {
  throw "Cannot use --tailscale-host and --remote-http together."
}

if ($tailscaleHost) {
  $tailscaleCmd = Get-Command $TailscaleBin -ErrorAction Stop
  $parsed = Parse-MeetingArgs -Arguments $positionalArgs.ToArray()
  if (-not $parsed.Audio) { throw "Audio file is required when using --tailscale-host." }
  Invoke-RemoteTranscription -Audio $parsed.Audio -Output $parsed.Output -Extras $parsed.Passthrough `
    -RemoteHost $tailscaleHost -RemoteUser $tailscaleUser -RemoteRepo $remoteRepo -RemoteWorkdir $remoteWorkdir `
    -KeepRemote:$keepRemote -TailscalePath $tailscaleCmd.Path
  return
}

if ($remoteHttp) {
  $parsed = Parse-MeetingArgs -Arguments $positionalArgs.ToArray()
  if (-not $parsed.Audio) { throw "Audio file is required when using --remote-http." }
  Invoke-HttpRemoteTranscription -Endpoint $remoteHttp -Audio $parsed.Audio -Output $parsed.Output -Extras $parsed.Passthrough -TimeoutSeconds $HttpTimeout
  return
}

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

uv run --project $ProjectRoot --python $PythonVersion meeting-notes $positionalArgs
