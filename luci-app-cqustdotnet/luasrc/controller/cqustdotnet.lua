module('luci.controller.cqustdotnet', package.seeall)

function index()
    -- upvalues 在此函数中是 nil，使用的话需要 require
    local app_name = require('luci.model.cbi.cqustdotnet.api.api').app_name

    entry({ 'admin', 'services', app_name }).dependent = true
    entry({ 'admin', 'services', app_name, 'reset_config' }, call('reset_config')).leaf = true
    if not nixio.fs.access('/etc/config/cqustdotnet') then
        return
    end
    e = entry({ "admin", "services", app_name }, alias('admin', 'services', app_name, 'index'), _('CQUST.net'), -10)
    e.dependent = true
    e.acl_depends = { "luci-app-cqustdotnet" }

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
local http = require('luci.http')
local util = require('luci.util')
local i18n = require('luci.i18n')

local is_running = false

function reset_config()
    -- TODO: 关闭正在运行的服务
    luci.sys.call('[ -f /usr/share/cqustdotnet/0_default_config ] && cp -f /usr/share/cqustdotnet/0_default_config /etc/config/cqustdotnet')
    luci.http.redirect(api.url())
end

function status()
    local status = {
        core_functions_running = is_running
    }

    luci.http.prepare_content('application/json')
    luci.http.write_json(status)
end

function get_log()
    luci.http.write(luci.sys.exec("[ -f '/var/log/cqustdotnet.log' ] && cat /var/log/cqustdotnet.log"))
end

function clear_log()
    luci.sys.call("echo '' > /var/log/cqustdotnet.log")
end
