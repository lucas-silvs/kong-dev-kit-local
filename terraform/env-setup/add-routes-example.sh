#!/bin/bash

# Script para adicionar rotas dinamicamente ao Kong via API Admin
# Certifique-se de que o Kong está rodando antes de executar este script

KONG_ADMIN_URL="http://localhost:8001"

echo "Adicionando Service de exemplo..."

# Criar um Service
curl -i -X POST $KONG_ADMIN_URL/services/ \
  --data "name=example-service" \
  --data "url=http://httpbin.org"

echo -e "\n\nAdicionando Route para o Service..."

# Criar uma Route para o Service
curl -i -X POST $KONG_ADMIN_URL/services/example-service/routes \
  --data "hosts[]=example.com" \
  --data "paths[]=/api"

echo -e "\n\nAdicionando outro Service..."

# Criar outro Service
curl -i -X POST $KONG_ADMIN_URL/services/ \
  --data "name=jsonplaceholder-service" \
  --data "url=https://jsonplaceholder.typicode.com"

echo -e "\n\nAdicionando Route para JSONPlaceholder..."

# Criar Route para JSONPlaceholder
curl -i -X POST $KONG_ADMIN_URL/services/jsonplaceholder-service/routes \
  --data "hosts[]=api.example.com" \
  --data "paths[]=/posts"

echo -e "\n\nListando todos os Services:"
curl -s $KONG_ADMIN_URL/services/ | jq '.data[] | {name: .name, url: .url}'

echo -e "\n\nListando todas as Routes:"
curl -s $KONG_ADMIN_URL/routes/ | jq '.data[] | {name: .name, paths: .paths, hosts: .hosts}'

echo -e "\n\nPara testar as rotas criadas:"
echo "curl -H 'Host: example.com' http://localhost:8000/api/get"
echo "curl -H 'Host: api.example.com' http://localhost:8000/posts"
