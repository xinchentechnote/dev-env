#!/bin/bash

set -e

# ========================
# 配置区（可按需修改）
# ========================
CA_CN="MyRootCA"
SERVER_CN="localhost"
DAYS=3650
KEY_SIZE=4096
OUT_DIR="./ssl"

# ========================
mkdir -p ${OUT_DIR}
cd ${OUT_DIR}

echo "🔧 Generating CA key and certificate..."

# 1. CA 私钥
openssl genrsa -out ca.key ${KEY_SIZE}

# 2. CA 自签证书
openssl req -x509 -new -nodes \
  -key ca.key \
  -sha256 \
  -days ${DAYS} \
  -out ca.crt \
  -subj "/CN=${CA_CN}"

echo "✅ CA generated: ca.key / ca.crt"

# ========================
echo "🔧 Generating server key and CSR..."

# 3. 服务端私钥
openssl genrsa -out server.key ${KEY_SIZE}

# 4. 服务端证书请求
openssl req -new \
  -key server.key \
  -out server.csr \
  -subj "/CN=${SERVER_CN}"

echo "✅ Server key and CSR generated"

# ========================
echo "🔧 Signing server certificate with CA..."

# 5. CA 签发服务端证书
openssl x509 -req \
  -in server.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out server.crt \
  -days ${DAYS} \
  -sha256

echo "✅ Server certificate signed"

# ========================
echo "🔍 Verifying certificate chain..."
openssl verify -CAfile ca.crt server.crt

echo ""
echo "🎉 All files generated successfully:"
echo "-----------------------------------"
ls -1 *.key *.crt 2>/dev/null
echo ""
echo "👉 Client only needs: ca.crt"
echo "👉 Server needs: server.crt + server.key"