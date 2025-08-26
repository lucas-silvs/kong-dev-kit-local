-- kong/plugins/jwt-cache-custom-plugin/handler.lua
local body_transformer    = require "kong.plugins.jwt-cache-custom-plugin.body_transformer"
local redis_kv            = require "kong.plugins.jwt-cache-custom-plugin.redis_kv"
local kong_meta           = require "kong.meta"

local transform_json_body = body_transformer.transform_json_body

local plugin              = {
  PRIORITY = 800,
  VERSION  = kong_meta.version,
}

-- função que o timer vai executar (cosocket permitido fora do body_filter)
local function save_tokens_to_redis(premature, conf, access_token, jwt, ttl)
  if premature then return end
  if not (access_token and jwt) then return end
  local ok, err = redis_kv.store_raw(conf, access_token, jwt, ttl)
  if not ok then
    kong.log.err("redis store_raw failed: ", err or "unknown")
  end
end

function plugin:header_filter(conf)
  -- vamos reescrever o body -> deixe o Nginx recalcular
  kong.response.clear_header("Content-Length")
end

function plugin:body_filter(conf)
  if kong.response.get_status() == 200 then
    local ctx = kong.ctx.plugin
    local eof = ngx.arg[2]

    if not ctx.did_transform then
      local body = kong.response.get_raw_body()
      local new_body, tokens, err = transform_json_body(body)
      if err then
        kong.log.warn("body transform failed: ", err)
        return
      end
      -- guarda tokens no ctx pra usar no EOF/timer
      ctx.tokens = tokens
      -- aplica body sem jwt
      kong.response.set_raw_body(new_body)
      ctx.did_transform = true
    end

    if eof and ctx.tokens then
      local ttl = (conf and conf.jwt_ttl) or 3600
      -- agenda escrita no Redis, sem travar o body_filter
      ngx.timer.at(0, save_tokens_to_redis, conf,
        ctx.tokens.access_token, ctx.tokens.jwt, ttl)
      ctx.tokens = nil
    end
  end
end

return plugin
