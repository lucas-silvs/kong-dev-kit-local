local body_transformer = require "kong.plugins.jwt-cache-custom-plugin.body_transformer"
local kong_meta = require "kong.meta"
local transform_json_body = body_transformer.transform_json_body

local plugin = {
  PRIORITY = 800,              -- set the plugin priority, which determines plugin execution order
  VERSION = kong_meta.version, -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}


function plugin:header_filter(conf)
  kong.response.clear_header("Content-Length")
end

-- runs in the 'body_filter_by_lua_block'
function plugin:body_filter(plugin_conf)
  -- your custom code here

  kong.log.info("iniciando plugin na fase de 'response'")

  -- kong.response.clear_header("Content-Length")

  local body = kong.response.get_raw_body()
  local json_body, err = transform_json_body(body)

  if err then
    kong.log.warn("body transform failed: " .. err)
    return
  end

  return kong.response.set_raw_body(json_body)
end

return plugin
