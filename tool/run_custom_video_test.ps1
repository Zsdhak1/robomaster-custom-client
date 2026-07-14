#requires -Version 5.1
<#
.SYNOPSIS
    一键启动本地自定义图传测试：Mosquitto + Windows 编码模拟器 + 可选 Flutter 客户端。
.DESCRIPTION
    1. 查找并启动本地 mosquitto broker（端口 1883）。
    2. 检查 Python 依赖与 protobuf 生成文件。
    3. 启动 encoder_simulator.py。
    4. 可选启动 Flutter 客户端。
.PARAMETER InputPath
    视频文件路径或摄像头索引（默认 0）。
.PARAMETER Broker
    MQTT broker IP（默认 127.0.0.1）。
.PARAMETER Port
    MQTT broker 端口（默认 1883）。
.PARAMETER NoFlutter
    不启动 Flutter 客户端。
.PARAMETER NoDisplay
    关闭编码模拟器的 OpenCV 调试窗口。
#>
param(
    [string]$InputPath = "0",
    [string]$Broker = "127.0.0.1",
    [int]$Port = 1883,
    [switch]$NoFlutter,
    [switch]$NoDisplay
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$simDir = Join-Path $repoRoot "tool" "custom_byte_block_simulator"

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# 1. 启动 mosquitto
function Start-Mosquitto {
    if (-not (Test-Command "mosquitto")) {
        Write-Host "ERROR: mosquitto 未找到。请安装 Mosquitto 并加入 PATH。" -ForegroundColor Red
        Write-Host "下载地址: https://mosquitto.org/download/"
        exit 1
    }

    # 检查端口是否已被占用（可能用户已手动启动）
    $listener = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listener) {
        Write-Host "端口 $Port 已被占用，假设 mosquitto 已运行。"
        return
    }

    Write-Host "启动 mosquitto (端口 $Port)..."
    Start-Process -FilePath "mosquitto" -ArgumentList "-p", $Port -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

# 2. 检查 Python 依赖
function Test-PythonEnv {
    Push-Location $simDir
    try {
        $missing = @()
        foreach ($pkg in @("cv2", "av", "paho.mqtt.client", "google.protobuf")) {
            $code = "import importlib; importlib.import_module('$pkg')"
            $proc = Start-Process -FilePath "python" -ArgumentList "-c", $code -WindowStyle Hidden -PassThru -Wait
            if ($proc.ExitCode -ne 0) {
                $missing += $pkg
            }
        }
        if ($missing) {
            Write-Host "缺少 Python 依赖: $($missing -join ', ')，正在安装..." -ForegroundColor Yellow
            python -m pip install -r requirements.txt
        }

        if (-not (Test-Path "robomaster_custom_client_pb2.py")) {
            Write-Host "生成 Protobuf Python 绑定..."
            python -m grpc_tools.protoc --python_out=. --proto_path=..\..\protos ..\..\protos\robomaster_custom_client.proto
        }
    } finally {
        Pop-Location
    }
}

# 3. 启动编码模拟器
function Start-Encoder {
    Push-Location $simDir
    try {
        $argsList = @(
            "encoder_simulator.py",
            "--input", $InputPath,
            "--broker", $Broker,
            "--port", "$Port"
        )
        if ($NoDisplay) {
            $argsList += "--no-display"
        }

        Write-Host "启动编码模拟器..."
        Start-Process -FilePath "python" -ArgumentList $argsList -NoNewWindow -Wait
    } finally {
        Pop-Location
    }
}

# 4. 启动 Flutter 客户端
function Start-FlutterClient {
    Push-Location $repoRoot
    try {
        Write-Host "启动 Flutter 客户端..."
        Start-Process -FilePath "flutter" -ArgumentList "run" -NoNewWindow
    } finally {
        Pop-Location
    }
}

# 主
Start-Mosquitto
Test-PythonEnv

if (-not $NoFlutter) {
    Start-FlutterClient
}

Start-Encoder

Write-Host "测试结束。"
