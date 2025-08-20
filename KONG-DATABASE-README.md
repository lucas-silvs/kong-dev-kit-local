# Kong com Banco de Dados - Configuração Atualizada

## O que foi alterado

A configuração foi atualizada para incluir um banco de dados PostgreSQL, permitindo que o Kong gerencie rotas dinamicamente via API Admin, ao invés do modo declarativo anterior.

### Principais mudanças:

1. **Banco de dados PostgreSQL adicionado**
   - Container: `kong-postgres`
   - Porta: 5432
   - Database: `kong`
   - Usuário/Senha: `kong/kong`

2. **Kong configurado para usar banco de dados**
   - `KONG_DATABASE=postgres` (ao invés de `off`)
   - Configuração de conexão com PostgreSQL
   - Remoção do modo declarativo (`kong.yml`)

3. **Scripts de inicialização**
   - `init-kong.sh`: Aguarda PostgreSQL e executa migrações
   - `add-routes-example.sh`: Exemplo de como adicionar rotas via API

## Como usar

### 1. Aplicar a infraestrutura
```bash
cd terraform/env-setup
terraform init
terraform apply
```

### 2. Verificar se os containers estão rodando
```bash
docker ps
```

Você deve ver:
- `kong-postgres` (PostgreSQL)
- `kong` (Kong Gateway)
- `konga-mongo` (MongoDB para Konga)
- `konga` (Interface administrativa)

### 3. Adicionar rotas dinamicamente

#### Via API REST:
```bash
# Executar o script de exemplo
./add-routes-example.sh
```

#### Ou manualmente:
```bash
# Criar um Service
curl -i -X POST http://localhost:8001/services/ \
  --data "name=meu-service" \
  --data "url=https://httpbin.org"

# Criar uma Route
curl -i -X POST http://localhost:8001/services/meu-service/routes \
  --data "hosts[]=meusite.com" \
  --data "paths[]=/api/v1"
```

#### Via Interface Konga:
1. Acesse: http://localhost:1337
2. Configure conexão com Kong: http://kong:8001
3. Use a interface gráfica para gerenciar services e routes

### 4. Testar as rotas
```bash
# Testar rota criada
curl -H 'Host: meusite.com' http://localhost:8000/api/v1/get
```

### 5. Monitorar logs
```bash
# Kong logs
docker logs kong

# PostgreSQL logs  
docker logs kong-postgres
```

## API Admin do Kong

Com o banco de dados habilitado, você pode usar todas as funcionalidades da API Admin:

- **Services**: http://localhost:8001/services/
- **Routes**: http://localhost:8001/routes/
- **Plugins**: http://localhost:8001/plugins/
- **Consumers**: http://localhost:8001/consumers/

## Vantagens do modo com banco de dados

1. **Rotas dinâmicas**: Adicione/remova rotas sem reiniciar
2. **Plugins por rota**: Configure plugins específicos para cada rota
3. **Consumers**: Gerencie autenticação e autorização
4. **Rate limiting**: Configure limites de taxa dinâmicos
5. **Interface gráfica**: Use Konga para gerenciamento visual

## Estrutura dos containers

```
kong-network (bridge)
├── kong-postgres:5432
├── kong:8000,8001,8443,8444
├── konga-mongo:27017
└── konga:1337
```
