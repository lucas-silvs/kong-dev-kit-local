-- handler.lua (trechos relevantes)
local body_transformer    = require "kong.plugins.jwt-cache-custom-plugin.body_transformer"
local redis_kv            = require "kong.plugins.jwt-cache-custom-plugin.redis_kv"
local kong_meta           = require "kong.meta"

local transform_json_body = body_transformer.transform_json_body

local plugin              = { PRIORITY = 800, VERSION = kong_meta.version }

local function save_tokens_to_redis(premature, conf, access_token, jwt, ttl)
  if premature or not (access_token and jwt) then return end
  local ok, err = redis_kv.store_raw(conf, access_token, jwt, ttl)
  if not ok then kong.log.err("redis store_raw failed: ", err or "unknown") end
end

function plugin:access(conf)
  kong.service.request.enable_buffering()
  -- forçar upstream a responder descompactado (evita gzip)
  if conf.disable_encoding then
    kong.service.request.set_header("Accept-Encoding", "identity")
  end
end

function plugin:header_filter(conf)
  kong.response.clear_header("Content-Length")
  -- se o upstream vier gzip e você não vai recomprimir, mantenha isso:
  kong.response.clear_header("Content-Encoding")
end

function plugin:body_filter(conf)
  if kong.response.get_status() ~= 200 then
    return
  end

  local body = kong.service.response.get_raw_body()

  local new_body, tokens, err = transform_json_body(body)
  if err then
    kong.log.warn("body transform failed: ", err)
    kong.response.set_raw_body([[{"message":"ocorreu erro interno"}]])
    return
  end

  -- aplica o body sem jwt
  kong.response.set_raw_body(new_body)

  -- grava no Redis fora do body_filter
  if tokens and tokens.access_token and tokens.jwt then
    local ttl = (conf and conf.jwt_ttl) or 3600
    ngx.timer.at(0, save_tokens_to_redis, conf, tokens.access_token, tokens.jwt, ttl)
  end
end

return plugin
