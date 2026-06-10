# RoboMaster 2026 Custom Client Protocol - Protobuf Compiler (PowerShell)
# Requires: protoc + protoc-gen-dart

$PROTO_DIR = "protos"
$OUT_DIR = "lib/generated"
$PROTO_FILE = "$PROTO_DIR/robomaster_custom_client.proto"

function Check-Tools {
    Write-Host "Checking protoc..."
    $protocVersion = protoc --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "protoc not found. Please install Protocol Buffers compiler."
        exit 1
    }
    Write-Host "  $protocVersion"

    Write-Host "Checking protoc-gen-dart..."
    $dartPlugin = Get-Command protoc-gen-dart -ErrorAction SilentlyContinue
    if (-not $dartPlugin) {
        Write-Warning "protoc-gen-dart not found in PATH."
        Write-Host "Install with: dart pub global activate protoc_plugin"
        Write-Host "Then add to PATH: %LOCALAPPDATA%\Pub\Cache\bin"
        exit 1
    }
    Write-Host "  Found: $($dartPlugin.Source)"
}

function Build-Proto {
    Write-Host "Generating Dart protobuf code..."
    if (-not (Test-Path $OUT_DIR)) {
        New-Item -ItemType Directory -Path $OUT_DIR -Force | Out-Null
    }

    $env:PATH = "$env:PATH;$env:LOCALAPPDATA\Pub\Cache\bin"

    protoc --dart_out="$OUT_DIR" -I"$PROTO_DIR" "$PROTO_FILE"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "protoc generation failed."
        exit 1
    }
    Write-Host "Done. Output: $OUT_DIR/"
}

function Clean-Generated {
    Write-Host "Cleaning generated files..."
    if (Test-Path "$OUT_DIR/*.dart") {
        Remove-Item "$OUT_DIR/*.dart" -Force
    }
    Write-Host "Done."
}

switch ($args[0]) {
    "check" { Check-Tools }
    "clean" { Clean-Generated }
    default { Build-Proto }
}
