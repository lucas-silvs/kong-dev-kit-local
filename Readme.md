# Ambiente de Desenvolvimento de Plugins Kong

Dev-kit para criar, rodar e testar plugins do Kong localmente usando Docker Compose, com Postgres, Redis (TLS), Konga e uma mock API.

## Pré‑requisitos

- Docker e Docker Compose
- OpenSSL (usado para gerar os certificados TLS do Redis)
- Opcional: Lua localmente para lint/testes (o runtime roda no container do Kong)

## Visão geral dos serviços e portas

- Kong Proxy: 8000 (HTTP), 8443 (HTTPS)
- Kong Admin API: 8001 (HTTP), 8444 (HTTPS)
- Postgres: 5432
- Redis (TLS): 6379
- Konga (UI): 1337
- Mock API (json-server): 3001

## Passo a passo (primeira execução)

1) Defina a senha do Redis

Crie um arquivo `.env` na raiz (ou copie de `.env.example`) e defina:

```
REDIS_PASSWORD=TroqueEstaSenha123!
```

2) Gere os certificados TLS do Redis

```sh
bash scripts/configure-redis-cert.sh
```

3) Suba os serviços

```sh
docker compose up -d
```

O container do Kong roda um script de init que aplica as migrações no Postgres e inicia o Kong automaticamente.

4) Acesse as UIs/serviços

- Konga: http://localhost:1337 (no primeiro acesso, crie o usuário admin e adicione uma conexão apontando para http://kong:8001)
- Mock API: http://localhost:3001 (dados em `mocks/db.json`)

## Desenvolvendo plugins

Coloque seu código em `kong/plugins/<nome-do-plugin>`:

```
kong/
    └── plugins/
            └── my-plugin/
                    ├── handler.lua
                    └── schema.lua
```

Para que o Kong carregue um plugin custom, inclua o nome dele na variável `KONG_PLUGINS` do `docker-compose.yaml` (separado por vírgula). Ex.: `KONG_PLUGINS: my-plugin,request-transformer,...`.

### Ciclo de desenvolvimento

- Alterou somente código Lua do plugin? Faça reload dos workers:

```sh
docker compose exec kong kong reload
```

- Adicionou um novo plugin (novo diretório) ou mudou `KONG_PLUGINS`? Recrie o container:

```sh
docker compose up -d --force-recreate kong
```

## Testes rápidos

- Verifique a Admin API:

```sh
curl -fsS http://localhost:8001/ | head -n 5
```

- Use o Konga para criar Services/Routes e anexar seus plugins; ou interaja via Admin API na porta 8001.

## Limpeza

Para parar e remover os containers:

```sh
docker compose down
```

## Dicas e solução de problemas

- Redis não sobe ou healthcheck falha: confirme que `.env` existe e `REDIS_PASSWORD` está definido. Os certificados em `redis/tls` devem existir (rode o script de configuração).
- Porta em uso: ajuste as portas mapeadas em `docker-compose.yaml` ou libere a porta no host.
- Konga não conecta ao Kong: dentro do Konga use a URL `http://kong:8001` (é o hostname do container do Kong na mesma rede Docker). Do host, a Admin API está em `http://localhost:8001`.
- Migrações do Kong: são executadas pelo script `scripts/init-kong.sh` ao iniciar o container; verifique os logs do container `kong` em caso de erro.
