# RoboMaster 2026 自定义客户端协议 - Protobuf 编译 Makefile
# 需要：protoc + protoc-gen-dart

PROTO_DIR := protos
OUT_DIR := lib/generated
PROTO_FILE := $(PROTO_DIR)/robomaster_custom_client.proto

.PHONY: all proto clean check

all: proto

# 从 .proto 生成 Dart 代码
proto: $(PROTO_FILE)
	@echo "Generating Dart protobuf code..."
	@mkdir -p $(OUT_DIR)
	protoc --dart_out=$(OUT_DIR) -I$(PROTO_DIR) $(PROTO_FILE)
	@echo "Done. Output: $(OUT_DIR)/"

# 检查 protoc 和 protoc-gen-dart 是否可用
check:
	@echo "Checking protoc..."
	@protoc --version
	@echo "Checking protoc-gen-dart..."
	@which protoc-gen-dart || echo "protoc-gen-dart not found. Install with: dart pub global activate protoc_plugin"

# 清理生成文件
clean:
	@echo "Cleaning generated files..."
	@rm -rf $(OUT_DIR)/*.dart
	@echo "Done."
