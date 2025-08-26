-- kong/plugins/jwt-cache-custom-plugin/redis_kv.lua
local redis = require "resty.redis"
local cjson = require "cjson.safe"

local _M = {}

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
