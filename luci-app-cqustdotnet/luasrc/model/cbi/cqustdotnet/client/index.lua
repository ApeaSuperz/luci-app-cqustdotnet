local api = require('luci.model.cbi.cqustdotnet.api.api')
local app_name = api.app_name

local map = Map(app_name)

-- TODO
-- map:append(Template(app_name .. '/global/status'))

return map
