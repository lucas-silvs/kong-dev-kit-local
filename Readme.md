# Ambiente de Desenvolvimento de Plugins Kong

Este repositório fornece uma maneira rápida e fácil para desenvolvedores configurarem e testarem seus próprios plugins Kong usando Terraform e Docker.

## Pré-requisitos

Certifique-se de ter os seguintes itens instalados em sua máquina:

- [Terraform](https://www.terraform.io/downloads.html) (>= 0.12)
- [Docker](https://docs.docker.com/get-docker/)
- [Lua](https://www.lua.org/download.html) (ou `brew install lua`)

## Primeiros Passos

### 2. Inicializar e Aplicar a Configuração do Terraform

Execute os seguintes comandos para inicializar o Terraform e criar os recursos necessários:

```sh
docker compose up
```

Isso irá:

1. Baixar a imagem Docker mais recente do Kong.
2. Criar um contêiner Docker para o Kong com as portas necessárias expostas.
3. Montar seu código de plugin e arquivo de configuração no contêiner Kong.

### 3. Desenvolver Seu Plugin

O código do seu plugin deve ser colocado no diretório `kong/plugins/<nome-do-plugin>`. A estrutura de arquivos deve ser algo como:

```

kong/
   └── plugins/
       └── my-plugin/
           ├── handler.lua
           └── schema.lua
```

### 5. Iniciar o Kong

Após colocar seu código de plugin e configuração, execute o seguinte comando para iniciar o Kong com seu plugin:

```sh
docker compose up -d --force-recreate kong
```

Este comando iniciará o Kong com a configuração especificada em `kong.yml`.

### 6. Testar Seu Plugin

Na URL http://localhost:1337, você pode acessar a interface gráfica do Konga para criar rotas, serviços e testar os novos plugins manualmente.

```sh
curl -i http://localhost:1337/
```

## Limpeza

Para destruir os recursos criados, execute:

```sh
docker compose down
```

Isso irá parar e remover o contêiner Docker e limpar quaisquer outros recursos criados pelo Terraform.

## Carregando Novos Plugins

Para carregar novos plugins, você deve realizar os seguintes passos:

### Incluir a nova pasta de plugin no diretório de plugins

```

kong/
   └── plugins/
       └── novo-plugin/
           ├── handler.lua
           └── schema.lua
```

### Recriar contêiner do Kong para carregar novos plugins

Para carregar o novo plugin no contêiner do Kong, será necessário realizar o replace com o Terraform:

```sh
docker compose up -d --force-recreate kong
```
