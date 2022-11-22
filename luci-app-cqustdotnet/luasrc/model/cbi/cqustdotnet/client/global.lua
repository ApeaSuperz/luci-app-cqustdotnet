local api = require('luci.model.cbi.cqustdotnet.api.api')

local app_name = api.app_name

map = Map(app_name)
map.pageaction = false  -- 不显示页面上的保存/应用按钮，由我们自定义的按钮来控制，这样保存效率更高且不会影响其它 luci app

section = map:section(NamedSection, 'config')
section.anonymous = true

option = section:option(Flag, 'enabled', '总开关')
option.rmempty = false

option = section:option(Value, 'network_detection_interval', '网络连通性检测间隔', '单位：秒')
option.rmempty = false
option.datatype = 'and(min(1), uinteger)'
option.default = 5

section = map:section(Table, { {} }--[[ 随便给 table 一个可索引对象，让 section 不会显示 "尚无任何配置" ]])

option = section:option(Button, 'commit')
option.inputtitle = '保存设置'
option.inputstyle = 'save'
option.write = function()
  map.uci:commit(app_name)
end

option = section:option(Button, 'apply')
option.inputtitle = '保存&应用设置'
option.inputstyle = 'apply'
option.write = function()
  map.uci:commit(app_name)
  api.sys.call(string.format('/etc/init.d/%s restart >/dev/null 2>&1 &', app_name))
  api.http.redirect(api.url())
end

return map
