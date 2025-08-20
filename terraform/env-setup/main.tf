terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0" // Specify the version or version constraint here
    }
    
    // If you are using the Kong provider, you should also specify it here
    kong = {
      source  = "kevholditch/kong"
      version = ">= 0.14.0" // Specify the version or version constraint for the Kong provider
    }

    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 2.13.0"
    }
  }
}

provider "local" {
  // Configuration options for the local provider (if any)
}

resource "docker_network" "kong_network" {
  name = "kong-network"
  driver = "bridge"
}

resource "docker_image" "kong" {
  name = "kong:latest" // You can specify a specific version instead of "latest"
}

resource "docker_image" "konga" {
  name = "pantsel/konga:latest"
}

resource "docker_image" "mongo" {
  name = "mongo:4.4"
}

resource "docker_image" "postgres" {
  name = "postgres:13"
}

resource "docker_container" "kong" {
  image = docker_image.kong.image_id

  name  = "kong"
  
  networks_advanced {
    name = docker_network.kong_network.name
    aliases = ["kong"]
  }

  ports {
    internal = 8000
    external = 8000
  }

  ports {
    internal = 8443
    external = 8443
  }

  ports {
    internal = 8001
    external = 8001
  }

  ports {
    internal = 8444
    external = 8444
  }

   env = [
    "KONG_DATABASE=postgres",
    "KONG_PG_HOST=kong-postgres",
    "KONG_PG_PORT=5432",
    "KONG_PG_DATABASE=kong",
    "KONG_PG_USER=kong",
    "KONG_PG_PASSWORD=kong",
    "KONG_PROXY_ACCESS_LOG=/dev/stdout",
    "KONG_ADMIN_ACCESS_LOG=/dev/stdout",
    "KONG_PROXY_ERROR_LOG=/dev/stderr",
    "KONG_ADMIN_ERROR_LOG=/dev/stderr",
    "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl",
    "KONG_PLUGINS=my-plugin",
  ]
  
  // Mound plugin code
  volumes {
    host_path      = "/${abspath(path.module)}/../../kong/plugins/my-plugin"
    container_path = "/usr/local/share/lua/5.1/kong/plugins/my-plugin"
  }
  
  // Mount initialization script
  volumes {
    host_path      = "${abspath(path.module)}/init-kong.sh"
    container_path = "/init-kong.sh"
  }

  command = ["/bin/sh", "/init-kong.sh"]
  
  restart = "unless-stopped"
  
  depends_on = [docker_container.postgres]
    
}

resource "docker_container" "postgres" {
  image = docker_image.postgres.image_id
  
  name = "kong-postgres"
  
  networks_advanced {
    name = docker_network.kong_network.name
    aliases = ["kong-postgres", "postgres"]
  }
  
  ports {
    internal = 5432
    external = 5432
  }
  
  env = [
    "POSTGRES_DB=kong",
    "POSTGRES_USER=kong",
    "POSTGRES_PASSWORD=kong"
  ]
  
  restart = "unless-stopped"
}

resource "docker_container" "mongo" {
  image = docker_image.mongo.image_id
  
  name = "konga-mongo"
  
  networks_advanced {
    name = docker_network.kong_network.name
    aliases = ["mongo", "konga-mongo"]
  }
  
  ports {
    internal = 27017
    external = 27017
  }
  
  env = [
    "MONGO_INITDB_DATABASE=konga"
  ]
  
  restart = "unless-stopped"
}

resource "docker_container" "konga" {
  image = docker_image.konga.image_id
  
  name = "konga"
  
  networks_advanced {
    name = docker_network.kong_network.name
    aliases = ["konga"]
  }
  
  ports {
    internal = 1337
    external = 1337
  }
  
  env = [
    "NODE_ENV=production",
    "KONGA_HOOK_TIMEOUT=120000",
    "DB_ADAPTER=mongo",
    "DB_URI=mongodb://konga-mongo:27017/konga",
    "KONGA_LOG_LEVEL=info"
  ]
  
  restart = "unless-stopped"
  
  depends_on = [docker_container.kong, docker_container.mongo]
}

