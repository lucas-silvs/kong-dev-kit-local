mkdir -p ./redis/tls
cd ./redis/tls

# 3.1) CA (autoridade certificadora)
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=redis-ca" \
  -out ca.crt

# 3.2) Chave do servidor
openssl genrsa -out redis.key 2048

# 3.3) CSR do servidor (atenção ao CN)
openssl req -new -key redis.key -subj "/CN=kong-redis" -out redis.csr

# 3.4) SANs (para validar por nome do host)
cat > san.conf <<'EOF'
subjectAltName=DNS:kong-redis,DNS:localhost,IP:127.0.0.1
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

# 3.5) Assina o cert do servidor com a CA
openssl x509 -req -in redis.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out redis.crt -days 825 -sha256 -extfile san.conf

# Permissões mais restritas na chave privada
chmod 600 redis.key