-- kong/plugins/jwt-search-cache-custom-plugin/handler.lua
local redis_kv  = require "kong.plugins.jwt-search-cache-custom-plugin.redis_kv"
local kong_meta = require "kong.meta"

local plugin    = { PRIORITY = 800, VERSION = kong_meta.version }

local function strip_bearer(v)
  if not v then return nil end
  -- remove espaços nas pontas e prefixo "Bearer " (case-insensitive)
  v = v:gsub("^%s+", ""):gsub("%s+$", "")
  v = v:gsub("^[Bb][Ee][Aa][Rr][Ee][Rr]%s+", "")
  return v
end

function plugin:access(conf)
  local hdr_name = conf.header_auth_to_replace
  if not hdr_name or hdr_name == "" then
    -- configuração faltando → 500
    return kong.response.exit(500, { message = "configuração inválida (header_auth_to_replace)" })
  end

  -- 1) ler header configurado
  local header_value = kong.request.get_header(hdr_name)
  if not header_value or header_value == "" then
    -- sem header → 401
    return kong.response.exit(401, { message = "credenciais ausentes" })
  end

  -- 2) normalizar (remover 'Bearer ')
  local key = strip_bearer(header_value)
  if not key or key == "" then
    return kong.response.exit(401, { message = "credenciais inválidas" })
  end

  -- 3) buscar no Redis (chave = valor do header já normalizado)
  local jwt, err = redis_kv.fetch_raw(conf, key)
  if err then
    kong.log.err("redis fetch failed: ", err)
    return kong.response.exit(500, { message = "erro interno" })
  end
  if not jwt then
    -- não encontrado → 401
    return kong.response.exit(401, { message = "não autorizado" })
  end
  kong.log.err("JWT encontrado no Redis para chave ", key, ": ", jwt)
  -- 4) substituir o MESMO header por "Bearer <JWT>"
  kong.service.request.set_header(hdr_name, "Bearer " .. jwt)

  -- segue o fluxo até o upstream já com o header substituído
end

return plugin
