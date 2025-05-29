#!/usr/bin/env bash
#
# protogen.sh ― generate Go protobuf + gRPC code
# Usage: ./protogen.sh [PROTO_DIR]
# ------------------------------------------------------------

set -euo pipefail

### 0. Config (override via CLI or env vars) ##################
PROTO_DIR="${1:-${PROTO_DIR:-proto}}"
OUT_DIR="$PWD/api/gen/go"

# Extra include paths (e.g., googleapis, well-known types)
EXTRA_INCLUDE=${EXTRA_INCLUDE:-}

### 1. Ensure tools exist ####################################

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌  $1 not found"; exit 1; }
}

need protoc

for PLUGIN in protoc-gen-go protoc-gen-go-grpc; do
  if ! command -v "$PLUGIN" >/dev/null 2>&1; then
    echo "➜  Installing $PLUGIN …"
    case "$PLUGIN" in
      protoc-gen-go)
        go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
        ;;
      protoc-gen-go-grpc)
        go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
        ;;
    esac
  fi
done

### 2. Create / clean output directory #######################
mkdir -p "$OUT_DIR"

### 3. Run protoc ###########################################
echo "➜  Generating stubs from $PROTO_DIR → $OUT_DIR"
echo $PWD
(
  # cd so paths=source_relative writes flat into OUT_DIR
  cd "$PROTO_DIR"

  # shellcheck disable=SC2046
  protoc \
    -I . \
    ${EXTRA_INCLUDE:+-I "$EXTRA_INCLUDE"} \
    --go_out="$OUT_DIR"          --go_opt=paths=source_relative \
    --go-grpc_out="$OUT_DIR"     --go-grpc_opt=paths=source_relative \
    $(find . -name '*.proto')
)

echo "✅  Done. Generated files are in $OUT_DIR"