module('luci.controller.cqustdotnet', package.seeall)

function index()
  -- upvalues 在此函数中是 nil，使用的话需要 require
  local app_name = require('luci.model.cbi.cqustdotnet.api.constants').LUCI_NAME

  entry({ 'admin', 'services', app_name }).dependent = true
  entry({ 'admin', 'services', app_name, 'reset_config' }, call('reset_config')).leaf = true
  if not nixio.fs.access('/etc/config/cqustdotnet') then
    return
  end
  e = entry({ 'admin', 'services', app_name }, alias('admin', 'services', app_name, 'index'), _('CQUST.net'), -10)
  e.dependent = true
  e.acl_depends = { 'luci-app-cqustdotnet' }

  -- Client
  entry({ 'admin', 'services', app_name, 'index' }, cbi(app_name .. '/client/global'), _('主页'), 1).dependent = true
  entry({ 'admin', 'services', app_name, 'accounts' }, cbi(app_name .. '/client/accounts'), _('账号'), 2).dependent = true
  entry({ 'admin', 'services', app_name, 'account' }, cbi(app_name .. '/client/account')).leaf = true
  entry({ 'admin', 'services', app_name, 'log' }, form(app_name .. '/client/log'), _('日志'), 999).leaf = true

  -- API
  entry({ 'admin', 'services', app_name, 'status' }, call('status')).leaf = true
  entry({ 'admin', 'services', app_name, 'get_log' }, call('get_log')).leaf = true
  entry({ 'admin', 'services', app_name, 'clear_log' }, call('clear_log')).leaf = true
end

local api = require('luci.model.cbi.cqustdotnet.api.api')
local accounts = require('luci.model.cbi.cqustdotnet.api.accounts')
local const = require('luci.model.cbi.cqustdotnet.api.constants')

function reset_config()
  ---@language Shell Script
  luci.sys.call([[
    /etc/init.d/cqustdotnet stop
    [ -f /usr/share/cqustdotnet/0_default_config ] && cp -f /usr/share/cqustdotnet/0_default_config /etc/config/cqustdotnet
  ]])
  luci.http.redirect(api.url())
end

function status()
  local status = {
    connector = is_process_running(const.LUCI_NAME .. '/connector.lua')
  }

  ---@type Account|nil
  local current_account = accounts.current()
  if current_account then
    status.account = string.format('%s (%s)', current_account.username, current_account.remark)
  end

  luci.http.prepare_content('application/json')
  luci.http.write_json(status)
end

function get_log()
  luci.http.write(luci.sys.exec("[ -f '/var/log/cqustdotnet.log' ] && cat /var/log/cqustdotnet.log"))
end

function clear_log()
  luci.sys.call("echo '' > /var/log/cqustdotnet.log")
end

function is_process_running(process_name)
  local advanced_ps = luci.sys.exec("ps --version 2>&1 | grep -c procps-ng | tr -d '\n'")
  if advanced_ps == '1' then
    return luci.sys.call(string.format("ps -efw | grep '%s' | grep -v grep >/dev/null", process_name)) == 0
  else
    return luci.sys.call(string.format("ps -w | grep '%s' | grep -v grep >/dev/null", process_name)) == 0
  end
end
