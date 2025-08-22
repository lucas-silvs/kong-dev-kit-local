local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "jwt-redis-handler"

local schema = {
  name = PLUGIN_NAME,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- Redis connection configuration
          { redis_host = {
              type = "string",
              required = true,
              default = "127.0.0.1" }},
          { redis_port = {
              type = "integer",
              required = true,
              default = 6379,
              between = { 1, 65535 } }},
          { redis_password = {
              type = "string",
              required = false }},
          { redis_database = {
              type = "integer",
              required = true,
              default = 0,
              between = { 0, 15 } }},
          { redis_timeout = {
              type = "number",
              required = true,
              default = 2000 }},
          { redis_keepalive_pool_size = {
              type = "integer",
              required = true,
              default = 10,
              between = { 1, 100 } }},
          { redis_keepalive_idle_timeout = {
              type = "integer",
              required = true,
              default = 10000 }},
          -- JWT token expiration time in Redis (in seconds)
          { jwt_ttl = {
              type = "integer",
              required = true,
              default = 3600,
              gt = 0 }},
        },
      },
    },
  },
}

return schema
