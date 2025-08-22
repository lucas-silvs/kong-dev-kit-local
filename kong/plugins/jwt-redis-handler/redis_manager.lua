local redis = require "resty.redis"
local cjson = require "cjson"

local _M = {}

-- Pool de conexões Redis
local redis_pool = {}

-- Função para criar uma nova conexão Redis
local function create_redis_connection(config)
    local red = redis:new()
    
    -- Configurar timeout
    red:set_timeout(config.redis_timeout)
    
    -- Conectar ao Redis
    local ok, err = red:connect(config.redis_host, config.redis_port)
    if not ok then
        return nil, err
    end
    
    -- Autenticar se senha for fornecida
    if config.redis_password then
        local ok, err = red:auth(config.redis_password)
        if not ok then
            return nil, err
        end
    end
    
    -- Selecionar database
    local ok, err = red:select(config.redis_database)
    if not ok then
        return nil, err
    end
    
    return red, nil
end

-- Função para obter uma conexão Redis do pool ou criar uma nova
function _M.get_redis_connection(config)
    local pool_key = string.format("%s:%s:%s", 
        config.redis_host, 
        config.redis_port, 
        config.redis_database)
    
    -- Tentar obter conexão do pool
    local red = redis_pool[pool_key]
    
    if red then
        -- Verificar se a conexão ainda está ativa
        local ok, err = red:ping()
        if ok then
            return red, nil
        else
            -- Redis connection from pool is not active, creating new connection
            redis_pool[pool_key] = nil
        end
    end
    
    -- Criar nova conexão
    local new_red, err = create_redis_connection(config)
    if not new_red then
        return nil, err
    end
    
    -- Adicionar ao pool
    redis_pool[pool_key] = new_red
    
    return new_red, nil
end

-- Função para armazenar JWT no Redis
function _M.store_jwt_token(config, access_token, jwt_token)
    local red, err = _M.get_redis_connection(config)
    if not red then
        return false, "Failed to get Redis connection: " .. (err or "unknown error")
    end
    
    -- Armazenar o JWT token com TTL
    local ok, err = red:setex(access_token, config.jwt_ttl, jwt_token)
    if not ok then
        return false, "Failed to store JWT token: " .. (err or "unknown error")
    end
    
    -- Manter conexão viva usando keepalive
    local ok, err = red:set_keepalive(
        config.redis_keepalive_idle_timeout, 
        config.redis_keepalive_pool_size
    )
    if not ok then
        -- Failed to set keepalive, but this is not critical
    end
    
    return true, nil
end

-- Função para fechar todas as conexões do pool (cleanup)
function _M.close_all_connections()
    for key, red in pairs(redis_pool) do
        pcall(function()
            red:close()
        end)
        redis_pool[key] = nil
    end
end

return _M
