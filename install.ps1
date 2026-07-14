# install.ps1 — codebase-memory-mcp 的 Windows 一键安装脚本。
#
# 用法：安装说明见 README.md。
#
# 环境变量：
#   CBM_DOWNLOAD_URL  覆盖下载基础 URL（用于测试）

$ErrorActionPreference = "Stop"

# 强制使用 TLS 1.2+，避免旧版 PowerShell 默认 TLS 1.0 被 GitHub 拒绝。
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$Repo = "DeusData/codebase-memory-mcp"
$InstallDir = "$env:LOCALAPPDATA\Programs\codebase-memory-mcp"
$BinName = "codebase-memory-mcp.exe"
$BaseUrl = if ($env:CBM_DOWNLOAD_URL) { $env:CBM_DOWNLOAD_URL } else { "https://github.com/$Repo/releases/latest/download" }

# 安全检查：拒绝非 HTTPS 下载 URL（纵深防御）。
if (-not $BaseUrl.StartsWith("https://") -and -not $BaseUrl.StartsWith("http://localhost") -and -not $BaseUrl.StartsWith("http://127.0.0.1")) {
    Write-Host "error: refusing non-HTTPS download URL: $BaseUrl" -ForegroundColor Red
    exit 1
}

# 从参数检测安装变体（--ui 或 --standard）。
$Variant = "standard"
$SkipConfig = $false
foreach ($arg in $args) {
    if ($arg -eq "--ui") { $Variant = "ui" }
    if ($arg -eq "--standard") { $Variant = "standard" }
    if ($arg -eq "--skip-config") { $SkipConfig = $true }
    if ($arg -like "--dir=*") { $InstallDir = $arg.Substring(6) }
}

Write-Host "codebase-memory-mcp installer (Windows)"
Write-Host "  variant: $Variant"
Write-Host "  target:  $InstallDir\$BinName"
Write-Host ""

# 构建下载 URL。
if ($Variant -eq "ui") {
    $Archive = "codebase-memory-mcp-ui-windows-amd64.zip"
} else {
    $Archive = "codebase-memory-mcp-windows-amd64.zip"
}
$Url = "$BaseUrl/$Archive"

# 下载压缩包。
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "cbm-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

Write-Host "Downloading $Archive..."
try {
    Invoke-WebRequest -Uri $Url -OutFile "$TmpDir\$Archive" -UseBasicParsing
} catch {
    Write-Host "error: download failed: $_" -ForegroundColor Red
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    exit 1
}


# 校验 checksum。
$ChecksumUrl = "$BaseUrl/checksums.txt"
try {
    Invoke-WebRequest -Uri $ChecksumUrl -OutFile "$TmpDir\checksums.txt" -UseBasicParsing
    $checksumLine = Get-Content "$TmpDir\checksums.txt" | Where-Object { $_ -like "*$Archive*" }
    if ($checksumLine) {
        $expected = ($checksumLine -split '\s+')[0]
        $actual = (Get-FileHash -Path "$TmpDir\$Archive" -Algorithm SHA256).Hash.ToLower()
        if ($expected -ne $actual) {
            Write-Host "error: CHECKSUM MISMATCH!" -ForegroundColor Red
            Write-Host "  expected: $expected"
            Write-Host "  actual:   $actual"
            Remove-Item -Recurse -Force $TmpDir
            exit 1
        }
        Write-Host "Checksum verified."
    }
} catch {
    Write-Host "warning: could not verify checksum (non-fatal)"
}

# 解压压缩包。
Write-Host "Extracting..."
Expand-Archive -Path "$TmpDir\$Archive" -DestinationPath $TmpDir -Force

$DlBin = Join-Path $TmpDir $BinName
if (-not (Test-Path $DlBin)) {
    # UI 变体在 zip 中可能使用不同文件名。
    $UiBin = Join-Path $TmpDir "codebase-memory-mcp-ui.exe"
    if (Test-Path $UiBin) {
        Rename-Item $UiBin $BinName
        $DlBin = Join-Path $TmpDir $BinName
    } else {
        Write-Host "error: binary not found after extraction" -ForegroundColor Red
        Remove-Item -Recurse -Force $TmpDir
        exit 1
    }
}

# 安装二进制文件。
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$Dest = Join-Path $InstallDir $BinName

# 处理运行中的旧版本：先改名让位。
if (Test-Path $Dest) {
    $OldDest = "$Dest.old"
    Remove-Item $OldDest -Force -ErrorAction SilentlyContinue
    try {
        Rename-Item $Dest $OldDest -ErrorAction Stop
    } catch {
        Write-Host "warning: could not rename existing binary (may be in use)"
    }
}

Copy-Item $DlBin $Dest -Force

# 验证安装结果。
try {
    $ver = & $Dest --version 2>&1
    Write-Host "Installed: $ver"
} catch {
    Write-Host "error: installed binary failed to run" -ForegroundColor Red
    Remove-Item -Recurse -Force $TmpDir
    exit 1
}

# 配置代码代理。
if ($SkipConfig) {
    Write-Host ""
    Write-Host "Skipping agent configuration (--skip-config)"
} else {
    Write-Host ""
    Write-Host "Configuring coding agents..."
    try {
        & $Dest install -y 2>&1 | Write-Host
    } catch {
        Write-Host "Agent configuration failed (non-fatal)."
        Write-Host "Run manually: codebase-memory-mcp install"
    }
}

# 添加到用户 PATH，无需管理员权限。
$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
    $env:PATH = "$env:PATH;$InstallDir"
    Write-Host "Added $InstallDir to user PATH"
}

# 清理临时文件。
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done! Restart your terminal and coding agent to start using codebase-memory-mcp."
