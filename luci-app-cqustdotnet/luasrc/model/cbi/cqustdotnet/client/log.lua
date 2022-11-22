local api = require('luci.model.cbi.cqustdotnet.api.api')

local app_name = api.app_name

local form = SimpleForm(app_name)
form.reset = false
form.submit = false
form:append(Template(app_name .. "/log/log"))

return form
