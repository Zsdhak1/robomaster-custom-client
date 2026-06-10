# RoboMaster 2026 Custom Client Protocol - Protobuf Compiler Makefile
# Requires: protoc + protoc-gen-dart

PROTO_DIR := protos
OUT_DIR := lib/generated
PROTO_FILE := $(PROTO_DIR)/robomaster_custom_client.proto

.PHONY: all proto clean check

all: proto

# Generate Dart code from .proto
proto: $(PROTO_FILE)
	@echo "Generating Dart protobuf code..."
	@mkdir -p $(OUT_DIR)
	protoc --dart_out=$(OUT_DIR) -I$(PROTO_DIR) $(PROTO_FILE)
	@echo "Done. Output: $(OUT_DIR)/"

# Check if protoc and protoc-gen-dart are available
check:
	@echo "Checking protoc..."
	@protoc --version
	@echo "Checking protoc-gen-dart..."
	@which protoc-gen-dart || echo "protoc-gen-dart not found. Install with: dart pub global activate protoc_plugin"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -rf $(OUT_DIR)/*.dart
	@echo "Done."
