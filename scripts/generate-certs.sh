#!/bin/bash
set -e

CERTS_DIR=$(mktemp -d)
VALIDITY_DAYS=3650

echo "Generating mTLS certificates..."
cd "$CERTS_DIR"

# Generate CA
openssl genrsa -out ca-key.pem 4096 2>/dev/null
openssl req -new -x509 -days $VALIDITY_DAYS -key ca-key.pem -sha256 -out ca-cert.pem \
  -subj "/C=BR/ST=Alagoas/L=Maceio/O=IFAL/OU=Student Ledger/CN=Student Ledger IPFS CA" 2>/dev/null

# Generate IPFS server certificate
openssl genrsa -out ipfs-server-key.pem 4096 2>/dev/null
openssl req -new -key ipfs-server-key.pem -out ipfs-server.csr \
  -subj "/C=BR/ST=Alagoas/L=Maceio/O=IFAL/OU=Student Ledger/CN=ipfs-server" 2>/dev/null

cat > ipfs-server-extfile.cnf <<EOF
subjectAltName = DNS:localhost,DNS:ipfs-orderer,DNS:ipfs-coordenacao,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

openssl x509 -req -days $VALIDITY_DAYS -sha256 \
  -in ipfs-server.csr -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out ipfs-server-cert.pem \
  -extfile ipfs-server-extfile.cnf 2>/dev/null

# Generate backend client certificate
openssl genrsa -out backend-client-key.pem 4096 2>/dev/null
openssl req -new -key backend-client-key.pem -out backend-client.csr \
  -subj "/C=BR/ST=Alagoas/L=Maceio/O=IFAL/OU=Student Ledger/CN=student-ledger-api" 2>/dev/null

cat > backend-client-extfile.cnf <<EOF
extendedKeyUsage = clientAuth
EOF

openssl x509 -req -days $VALIDITY_DAYS -sha256 \
  -in backend-client.csr -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out backend-client-cert.pem \
  -extfile backend-client-extfile.cnf 2>/dev/null

echo ""
echo "========================================"
echo "Add to student-ledger-ipfs/.env:"
echo "========================================"
echo ""
echo "IPFS_TLS_CA_CERT=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ca-cert.pem)\""
echo ""
echo "IPFS_TLS_SERVER_CERT=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ipfs-server-cert.pem)\""
echo ""
echo "IPFS_TLS_SERVER_KEY=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ipfs-server-key.pem)\""
echo ""
echo "========================================"
echo "Add to student-ledger-api/.env:"
echo "========================================"
echo ""
echo "IPFS_TLS_CA_CERT=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ca-cert.pem)\""
echo ""
echo "IPFS_TLS_CLIENT_CERT=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' backend-client-cert.pem)\""
echo ""
echo "IPFS_TLS_CLIENT_KEY=\"$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' backend-client-key.pem)\""

# Cleanup
rm -rf "$CERTS_DIR"
