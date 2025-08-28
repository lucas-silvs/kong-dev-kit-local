-- kong/plugins/jwt-cache-custom-plugin/redis_kv.lua
local redis = require "resty.redis"
local has_cluster, rediscluster = pcall(require, "resty.rediscluster")
if not has_cluster then
    -- algumas distros instalam o módulo como "rediscluster"
    has_cluster, rediscluster = pcall(require, "rediscluster")
end

local _M = {}

local function parse_cluster_nodes(conf)
    local nodes = {}
    for _, hp in ipairs(conf.redis_cluster_nodes or {}) do
        local host, port = tostring(hp):match("^%s*([^:]+):(%d+)%s*$")
        if host and port then
            nodes[#nodes + 1] = { ip = host, port = tonumber(port) }
        end
    end
    return nodes
end

local function red_connect_cluster(conf)
    if not has_cluster then
        return nil, "kong-redis-cluster (resty.rediscluster) não instalado"
    end

    local serv_list = parse_cluster_nodes(conf)
    if #serv_list == 0 then
        return nil, "redis_cluster_nodes vazio"
    end

    local params = {
        -- iguais ao exemplo do README
        name                    = conf.redis_cluster_name or "jwt-cache-cluster",
        serv_list               = serv_list,
        dict_name               = conf.redis_cluster_lock_dict or "kong_locks",
        refresh_lock_key        = conf.redis_cluster_refresh_lock_key or "redis_cluster_slots_refresh_lock",
        keepalive_timeout       = conf.redis_keepalive_idle_timeout or 60000,
        keepalive_cons          = conf.redis_keepalive_pool_size or 100,
        connect_timeout         = conf.redis_timeout or 2000,
        read_timeout            = conf.redis_timeout or 2000,
        send_timeout            = conf.redis_timeout or 2000,
        lock_timeout            = conf.redis_cluster_lock_timeout or 5,
        max_redirection         = conf.redis_cluster_max_redirection or 5,
        max_connection_attempts = conf.redis_cluster_max_connection_attempts or 1,

        -- auth (ACL ou requirepass)
        auth                    = (conf.redis_password and conf.redis_password ~= "") and conf.redis_password or nil,
        auth_user               = (conf.redis_username and conf.redis_username ~= "") and conf.redis_username or nil,

        -- TLS (a lib repassa pro lua-resty-redis)
        connect_opts            = {
            ssl         = conf.redis_ssl and true or false,
            ssl_verify  = conf.redis_ssl_verify and true or false,
            server_name = conf.redis_server_name,
        },
    }

    local red, err = rediscluster:new(params)
    if not red then
        return nil, "falha ao criar cliente cluster: " .. (err or "desconhecido")
    end
    return red
end

local function is_present(x) return x and x ~= "" end

local function red_connect(conf)
    local red = redis:new()

    -- timeouts (1 valor para connect/send/read)
    if red.set_timeouts then
        red:set_timeouts(conf.redis_timeout, conf.redis_timeout, conf.redis_timeout)
    else
        red:set_timeout(conf.redis_timeout)
    end

    -- pool separado por host:port:db + modo (tls/plain) + usuário
    local pool_key = string.format("%s:%d:%d:%s:%s",
        conf.redis_host,
        conf.redis_port,
        tonumber(conf.redis_database or 0),
        conf.redis_ssl and "tls" or "plain",
        conf.redis_username or "-"
    )

    -- >>> aqui seguimos o padrão do plugin cluster: passamos TLS no connect_opts
    -- (em vez de chamar sslhandshake manualmente)
    local connect_opts = {
        pool        = pool_key,
        ssl         = conf.redis_ssl and true or false,
        ssl_verify  = conf.redis_ssl_verify and true or false,
        server_name = conf.redis_server_name, -- SNI (use um hostname que case com o cert)
        -- opcionalmente, você pode definir pool_size/backlog como no cluster
        -- pool_size = 20, backlog = 10
    }

    local ok, err = red:connect(conf.redis_host, conf.redis_port, connect_opts)
    if not ok then
        return nil, "failed to connect to Redis: " .. (err or "unknown")
    end

    -- se é conexão nova (não reutilizada), faz AUTH/SELECT
    local times, err2 = red:get_reused_times()
    if err2 then
        return nil, "failed to get reuse times: " .. (err2 or "unknown")
    end

    if times == 0 then
        -- AUTH: ACL (username+password) ou legado (somente password)
        if is_present(conf.redis_password) then
            local okp, errp
            if is_present(conf.redis_username) then
                okp, errp = red:auth(conf.redis_username, conf.redis_password)
            else
                okp, errp = red:auth(conf.redis_password)
            end
            if not okp then
                return nil, "failed to auth Redis: " .. (errp or "unknown")
            end
        end

        if conf.redis_database and conf.redis_database ~= 0 then
            local oks, errs = red:select(conf.redis_database)
            if not oks then
                return nil, "failed to select Redis DB: " .. (errs or "unknown")
            end
        end
    end

    return red
end

local function set_keepalive(red, conf)
    local ok, err = red:set_keepalive(
        conf.redis_keepalive_idle_timeout or 10000,
        conf.redis_keepalive_pool_size or 100
    )
    if not ok then
        return nil, "failed to set Redis keepalive: " .. (err or "unknown")
    end
    return true
end

-- grava string crua com TTL (EX)
function _M.store_raw(conf, key, value, ttl)
    if conf.redis_cluster then
        local red, err = red_connect_cluster(conf)
        if not red then return nil, err end

        local ok, e = red:set(key, value)
        if not ok then return nil, e end
        if ttl and ttl > 0 then
            local ok2, e2 = red:expire(key, ttl)
            if not ok2 then return nil, e2 end
        end
        return true
    end


    if type(key) ~= "string" then
        return nil, "key must be a string"
    end
    if type(value) ~= "string" then
        return nil, "value must be a string"
    end

    local red, errc = red_connect(conf)
    if not red then
        return nil, errc
    end

    red:init_pipeline()
    red:set(key, value)
    if ttl and ttl > 0 then
        red:expire(key, ttl)
    end
    local _, err = red:commit_pipeline()
    local _ = set_keepalive(red, conf)

    if err then
        return nil, err
    end
    return true
end

-- opcional: leitura crua
function _M.fetch_raw(conf, key)
    if conf.redis_cluster then
        local red, err = red_connect_cluster(conf)
        if not red then return nil, err end
        local val, e = red:get(key)
        if e then return nil, e end
        if val == ngx.null then return nil end
        return val
    end

    local red, errc = red_connect(conf)
    if not red then
        return nil, errc
    end
    local val, err = red:get(key)
    local _ = set_keepalive(red, conf)
    if err then return nil, err end
    if val == ngx.null then return nil end
    return val
end

return _M
