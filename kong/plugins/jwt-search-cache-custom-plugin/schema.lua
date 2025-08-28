local typedefs = require "kong.db.schema.typedefs"

return {
    name = "jwt-search-cache-custom-plugin",
    fields = {
        { consumer = typedefs.no_consumer },
        { protocols = typedefs.protocols_http },
        {
            config = {
                type = "record",
                fields = {


                    -- TTL do JWT quando não houver exp conhecido
                    { header_auth_to_replace = { type = "string", required = true } },

                    -- liga/desliga cluster mode
                    { redis_cluster = { type = "boolean", required = false, default = false } },

                    -- lista de nós "host:port" (apenas se cluster=true)
                    {
                        redis_cluster_nodes = {
                            type = "array",
                            required = false,
                            elements = { type = "string", match = "^%S+:%d+$" },
                        }
                    },


                    -- Redis (básico)
                    { redis_host = { type = "string", required = false, default = "127.0.0.1" } },
                    { redis_port = { type = "integer", required = false, default = 6379 } },
                    { redis_database = { type = "integer", required = false, default = 0 } },
                    { redis_timeout = { type = "integer", required = false, default = 2000 } },
                    { redis_keepalive_pool_size = { type = "integer", required = false, default = 100 } },
                    { redis_keepalive_idle_timeout = { type = "integer", required = false, default = 60000 } },


                    { redis_username = { type = "string", required = false } },
                    -- autenticação "legacy" (somente senha)
                    { redis_password = { type = "string", required = false, encrypted = true } },


                    { redis_ssl = { type = "boolean", required = false, default = false } },
                    { redis_ssl_verify = { type = "boolean", required = false, default = false } },
                    { redis_server_name = { type = "string", required = false } },
                },
            },
        },
    },
}
