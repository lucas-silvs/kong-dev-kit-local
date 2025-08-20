local http = require "resty.http"
local kong = kong

local HttpConnector = {}

function HttpConnector.send_data_to_remote(endpoint, data)
  local httpc = http.new()
  local res, err = httpc:request_uri(endpoint, {
    method = "POST",
    body = data,
    headers = {
      ["Content-Type"] = "application/json",
    }
  })

  if not res then
    return nil, err
  end

  return res.body, res.status
end

return HttpConnector