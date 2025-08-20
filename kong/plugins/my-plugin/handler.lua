local kong = kong
local HttpConnector = require "kong.plugins.my-plugin.http-connector"

local MyPlugin = {
  PRIORITY = 1000,
  VERSION = "0.1",
}

function MyPlugin:access(conf)
  -- Extract the source IP
  local source_ip = kong.client.get_ip()
  
  -- Extract the full URL path (note that this does not include the query string)
  local full_url = kong.request.get_scheme() .. "://" .. kong.request.get_host() .. ":" .. kong.request.get_port() .. kong.request.get_path()

  -- Prepare the data to send
  local data_to_send = {
    source_ip = source_ip,
    full_url = full_url,
  }

  -- Serialize the data to JSON
  local cjson = require "cjson"
  local json_data = cjson.encode(data_to_send)

  -- Define the remote HTTP endpoint you want to send the data to
  local remote_http_endpoint = "http://webhook.site/4e796b8f-5e2f-4244-b1b8-8fb627fc3050"

  -- Send the data to the remote HTTP endpoint
  local response, status = HttpConnector.send_data_to_remote(remote_http_endpoint, json_data)

  if not response then
    kong.log.err("Failed to send data to remote endpoint: ", status)
    -- Handle error (e.g., you could decide to just log the error, or return an error response to the client)
  end
end

return MyPlugin