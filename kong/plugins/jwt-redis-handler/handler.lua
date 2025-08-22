local cjson = require "cjson"
local redis_manager = require "kong.plugins.jwt-redis-handler.redis_manager"

local plugin = {
    PRIORITY = 1000, -- define a prioridade do plugin
    VERSION = "1.0.0",
}

-- Função auxiliar para validar se o response body é um JSON válido
local function is_valid_json(str)
    if not str or str == "" then
        return false
    end

    local ok, _ = pcall(cjson.decode, str)
    return ok
end

-- Função auxiliar para extrair campos do JSON
local function extract_tokens_from_response(body)
    if not body or body == "" then
        return nil, nil, "Response body is empty"
    end

    local ok, json_data = pcall(cjson.decode, body)
    if not ok then
        return nil, nil, "Invalid JSON in response body"
    end

    local access_token = json_data.access_token
    local jwt_token = json_data.jwt

    if not access_token then
        return nil, nil, "Missing 'access_token' field in response"
    end

    if not jwt_token then
        return nil, nil, "Missing 'jwt' field in response"
    end

    return access_token, jwt_token, nil
end

-- Função auxiliar para remover campo JWT do response body
local function remove_jwt_from_response(body)
    local ok, json_data = pcall(cjson.decode, body)
    if not ok then
        return body -- Retorna o body original se não conseguir decodificar
    end

    -- Remove o campo jwt
    json_data.jwt = nil

    -- Recodifica o JSON
    local ok, new_body = pcall(cjson.encode, json_data)
    if not ok then
        return body -- Retorna o body original se não conseguir codificar
    end

    return new_body
end

-- Handler para interceptar o response
function plugin:response(plugin_conf)
    local status = kong.response.get_status()

    -- Verificar se status é 200
    if status ~= 200 then
        kong.log.debug("Response status is not 200, status: ", status)
        kong.response.exit(401, {
            error = "Unauthorized",
            message = "Response status is not 200. Status: " .. tostring(status)
        })
        return
    end

    -- Obter o response body
    local body = kong.response.get_raw_body()

    -- Verificar se existe response body válido
    if not body or body == "" then
        kong.log.debug("Response body is empty")
        kong.response.exit(401, {
            error = "Unauthorized",
            message = "Response body is empty"
        })
        return
    end

    -- Verificar se o body é um JSON válido
    if not is_valid_json(body) then
        kong.log.debug("Response body is not valid JSON")
        kong.response.exit(401, {
            error = "Unauthorized",
            message = "Response body is not valid JSON"
        })
        return
    end

    -- Extrair access_token e jwt do response body
    local access_token, jwt_token, extract_err = extract_tokens_from_response(body)
    if extract_err then
        kong.log.debug("Error extracting tokens: ", extract_err)
        kong.response.exit(401, {
            error = "Unauthorized",
            message = extract_err
        })
        return
    end

    -- Armazenar JWT no Redis
    local success, redis_err = redis_manager.store_jwt_token(plugin_conf, access_token, jwt_token)
    if not success then
        kong.log.err("Failed to store JWT in Redis: ", redis_err)
        kong.response.exit(500, {
            error = "Internal Server Error",
            message = "Failed to store JWT token: " .. (redis_err or "unknown error")
        })
        return
    end

    kong.log.debug("JWT token stored successfully in Redis for access_token: ", access_token)

    -- Remover campo JWT do response body
    local new_body = remove_jwt_from_response(body)

    -- Atualizar o response body
    kong.response.set_raw_body(new_body)

    -- Atualizar o Content-Length header se necessário
    kong.response.set_header("Content-Length", tostring(#new_body))

    kong.log.debug("JWT field removed from response body successfully")
end

-- Handler de inicialização do worker
function plugin:init_worker()
    kong.log.debug("JWT Redis Handler plugin initialized")
end

-- Handler de configuração
function plugin:configure(configs)
    kong.log.notice("JWT Redis Handler plugin configured with ", (configs and #configs or 0), " configs")
end

return plugin
