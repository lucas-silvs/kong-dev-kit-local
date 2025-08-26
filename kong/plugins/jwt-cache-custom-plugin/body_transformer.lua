-- kong/plugins/jwt-cache-custom-plugin/body_transformer.lua
local cjson = require("cjson.safe").new()
local encode = cjson.encode
local decode = cjson.decode

cjson.decode_array_with_array_mt(true)

local function parse_json(body)
  if not body then return nil end
  local ok, res = pcall(decode, body)
  if ok then return res end
end

local _M = {}

function _M.transform_json_body(buffered_data)
  local json_body = parse_json(buffered_data)
  if json_body == nil then
    return nil, nil, "failed parsing json body"
  end

  local access_token = json_body["access_token"]
  local jwt          = json_body["jwt"]

  -- remove o campo jwt do response
  json_body["jwt"]   = nil

  local new_body     = encode(json_body)
  local tokens       = { access_token = access_token, jwt = jwt }

  return new_body, tokens, nil
end

return _M
