local api = require('luci.model.cbi.cqustdotnet.api.api')

local uci = api.uci
local app_name = api.app_name

map = Map(api.app_name)
map.pageaction = false  -- 不显示页面上的保存/应用按钮

-- 账号列表
section = map:section(TypedSection, 'accounts')
section.addremove = true  -- 添加/删除按钮
section.anonymous = true
section.sortable = true  -- 允许排序
section.template = 'cbi/tblsection'
section.extedit = api.url('account', '%s')  -- 编辑按钮
section.create = function(self)
  local existed
  uci:foreach(app_name, 'accounts', function(account)
    if not account['remark'] or not account['username'] or not account['password'] then
      existed = account['.name']
    end
  end)

  local id = existed
  if not existed then
    id = api.gen_uuid()
    TypedSection.create(self, id)
  end

  luci.http.redirect(self.extedit:format(id))
end

-- 账号备注
option = section:option(DummyValue, 'remark', '备注')
option.width = 'auto'
option.rmempty = false

-- 用户名
option = section:option(DummyValue, 'username', '用户名')
option.width = 'auto'
option.rmempty = false

section = map:section(Table, { {} }--[[ 随便给 table 一个可索引对象，让 section 不会显示 "尚无任何配置" ]])

option = section:option(Button, 'commit')
option.inputtitle = '保存更改'
option.inputstyle = 'save'
option.write = function()
  map.uci:commit(app_name)
end

return map
