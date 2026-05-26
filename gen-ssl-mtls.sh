#!/bin/bash
set -e

# ========== 配置区 ==========
OUT_DIR="./ssl-mtls"
CA_CN="MyRootCA"
SERVER_CN="localhost"
SERVER_IP="127.0.0.1"
DAYS=3650
KEY_SIZE=4096

# 多客户端：在此添加客户端标识（CN），空格分隔
CLIENTS=( "client-app-a" "client-app-b" "client-device-01" )

# SAN 模板
SAN_SERVER="DNS:${SERVER_CN},IP:${SERVER_IP}"
# ==============================

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

echo "🔐 [1/5] Generating CA key & certificate..."
openssl genrsa -out ca.key "${KEY_SIZE}"
openssl req -x509 -new -nodes \
  -key ca.key -sha256 -days "${DAYS}" \
  -out ca.crt \
  -subj "/CN=${CA_CN}"

# ---- 服务端证书 ----
echo "🖥  [2/5] Generating server key & CSR..."
openssl genrsa -out server.key "${KEY_SIZE}"
openssl req -new \
  -key server.key \
  -out server.csr \
  -subj "/CN=${SERVER_CN}"

cat > server_ext.cnf <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = ${SAN_SERVER}
EOF

echo "📜 [3/5] Signing server certificate with CA..."
openssl x509 -req \
  -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt \
  -days "${DAYS}" -sha256 \
  -extfile server_ext.cnf

# ---- 多客户端证书 ----
mkdir -p clients
for CNAME in "${CLIENTS[@]}"; do
  echo "👤  Generating client: ${CNAME} ..."
  CK="clients/${CNAME}.key"
  CC="clients/${CNAME}.crt"
  CS="clients/${CNAME}.csr"

  openssl genrsa -out "${CK}" "${KEY_SIZE}"
  openssl req -new \
    -key "${CK}" \
    -out "${CS}" \
    -subj "/CN=${CNAME}"

  cat > client_ext.cnf <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
subjectAltName = DNS:${CNAME}
EOF

  openssl x509 -req \
    -in "${CS}" \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${CC}" \
    -days "${DAYS}" -sha256 \
    -extfile client_ext.cnf

  rm -f client_ext.cnf "${CS}"
done

rm -f server.csr server_ext.cnf ca.srl

echo ""
echo "✅ All mTLS certificates generated!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " CA (trust):      ca.crt / ca.key"
echo " Server:          server.crt + server.key"
echo " Clients (${#CLIENTS[@]}): ssl-mtls/clients/*.crt + *.key"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👉 服务端配置:   trustManager(ca.crt) + forServer(server.crt, server.key) + clientAuth(REQUIRE)"
echo "👉 客户端配置:   trustManager(ca.crt) + keyManager(clientX.crt, clientX.key)"