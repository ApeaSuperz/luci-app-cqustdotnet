#!/usr/bin/lua

local nixio = require('nixio')
local http = require('luci.http')
local json = require('luci.jsonc')
local api = require('luci.model.cbi.cqustdotnet.api.api')

local uci = api.uci
local app_name = api.app_name

local LOCK_FILE = '/tmp/lock/' .. app_name .. '_script.lock'

local function is_file_exists(filename)
  return nixio.fs.stat(filename, 'type') == 'reg'
end

---
--- 尝试访问认证重定向主机，返回成功与否。
---
--- 参数 max_retry 为最大重试次数，不传默认为 0 不重试。
---
--- 一般情况下，不能访问认证重定向主机说明认证已经成功，少数情况是校园网故障，
--- 无需访问互联网判断。
---@overload fun():boolean
---@param max_retry number
---@return boolean
local function can_access_auth(max_retry)
  local max_try = (max_retry or 0) + 1  -- 默认不重试

  local request = nixio.socket('inet', 'stream')
  request:setopt('socket', 'sndtimeo', 1)

  for _ = 1, max_try do
    if request:connect('123.123.123.123', 80) then
      request:close()
      return true
    end
    request:shutdown()
  end
  request:close()
  return false
end

---
--- 获取可能可用的账号，不保证可以成功登录。账号是否可用应该在登录时判断并记录。
---
--- 设定的起始账号都不会被包含在返回结果内，最终的返回值是账号的 .name 属性。
--- 无可用的账号时返回 nil。
---@overload fun():string
---@overload fun(from:string):string
---@param from string|nil
---@param to string
---@return string|nil
local function get_possible_account_name(from, to)
  local start_check = not from
  local account, index = nil, 0
  while not account do
    if not start_check then
      local datatype, account_name = uci:get(app_name, '@accounts[' .. index .. ']')

      -- 没有找到起始账号
      if not datatype then
        return nil
      end

      -- 找到起始账号，可以开始做额外检查了
      if account_name == from then
        start_check = true
      end
    else
      account = uci:get_all(app_name, '@accounts[' .. index .. ']')

      -- 遍历到最后一个账号了
      if not account then
        -- 没有指定起始账号的情况下，遍历到最后一个账号，说明没有可用账号
        if not from then
          return nil
        end

        -- 指定了起始账号的情况下，在起始账号之前的账号还没有做详细校验
        return get_possible_account_name(nil, from)
      end

      -- 限制了结束账号
      if account['.name'] == to then
        return nil
      end

      -- TODO: 检查账号是否被禁封
    end
    index = index + 1
  end
  return account['.name']
end

local redirect_request_http_headers
local function get_redirect_request_http_headers()
  if not redirect_request_http_headers then
    redirect_request_http_headers = table.concat({
      'GET / HTTP/1.1',
      'Host: 123.123.123.123',
      'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
      'Accept: */*',
      'Accept-Language: zh-CN,zh;q=0.8',
      'Accept-Encoding: gzip, deflate',
      'Connection: keep-alive',
      'Upgrade-Insecure-Requests: 1'
    }, '\r\n')
  end
  return redirect_request_http_headers
end

---
--- 获取重定向时给定的参数，验证登录时要用。
---
--- 成功返回验证登录主机地址和参数，参数是一个 x-www-form-urlencoded 格式的字符串。失败返回 nil。
---@overload fun():string
---@return string,string | nil
local function get_auth_query_params(max_retry)
  local max_try = (max_retry or 0) + 1  -- 默认不重试
  for attempt = 1, max_try do
    local request = nixio.socket('inet', 'stream')
    request:setopt('socket', 'sndtimeo', 1)  -- 发送 1 秒超时
    if not request:connect('123.123.123.123', 80) then
      request:close()
      api.log('认证参数获取：无法连接到认证服务器，第 ', attempt, '/', max_try, ' 次尝试')
    else
      request:setopt('socket', 'rcvtimeo', 1)  -- 接收 1 秒超时
      request:send(get_redirect_request_http_headers())
      ---@type string|nil
      local response = request:recv(1024)
      request:close()
      if not response or #response == 0 then
        api.log('认证参数获取：无法从认证服务器接收响应，第 ', attempt, '/', max_try, ' 次尝试')
      else
        local auth_host = response:match('://(.-)/')
        local query_params = response:match("%?(.+)'<")
        if not auth_host or not query_params then
          api.log('认证参数获取：无法从响应中获取认证参数，第 ', attempt, '/', max_try, ' 次尝试')
        else
          return auth_host, query_params
        end
      end
    end
  end
end

local function get_auth_request_headers(host, body_length)
  return table.concat({
    'POST /eportal/InterFace.do?method=login HTTP/1.1',
    'Host: ' .. host,
    'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
    'Accept: */*',
    'Accept-Language: zh-CN,zh;q=0.8',
    'Accept-Encoding: gzip, deflate',
    'Content-Type: application/x-www-form-urlencoded',
    'Content-Length: ' .. body_length,
    'Origin: http://' .. host,
    'Connection: keep-alive'
  }, '\r\n')
end

local function get_auth_request_body(username, password, query_params)
  return string.format('userId=%s&password=%s&service=&queryString=%s&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false',
      username, password, http.urlencode(http.urlencode(query_params)))
end

---
--- 尝试登录，返回成功与否。
---
--- 该函数还负责记录失败时的信息到账号内，比如账号被禁封的话，禁封到何时。
---
--- HTTP/1.1 200 OK
--- X-Frame-Options: SAMEORIGIN
--- X-XSS-Protection: 1; mode=block
--- X-Powered-By:
--- Cache-Control: max-age=0
--- Expires: Wed, 31 Dec 1969 23:59:59 GMT
--- Pragma: no-cache
--- Set-Cookie: JSESSIONID=3FDC359EC7EC3B030F781F34B1B1BA1F; Path=/eportal; HttpOnly
--- Content-Type: text/html
--- Content-Length: 220
--- Date: Sat, 19 Nov 2022 11:53:50 GMT
--- Server:
---
--- {"userIndex":"66353830653066653331353432646135396664336435313639643131373064325f3137322e32312e38312e3233375f32303232353230383933","result":"success","message":"","forwordurl":null,"keepaliveInterval":0,"validCodeUrl":""}
---
---@param account table<string, string>
---@return boolean
local function try_auth(account)
  if not account then
    return false
  end

  local auth_host, query_params = get_auth_query_params()
  if not auth_host or not query_params then
    api.log('认证：无法获取认证参数')
    return false
  end

  local auth_request_body = get_auth_request_body(account['username'], account['password'], query_params)
  local auth_request_headers = get_auth_request_headers(auth_host, #auth_request_body)
  local auth_request_content = auth_request_headers .. '\r\n\r\n' .. auth_request_body
  local request = nixio.socket('inet', 'stream')
  request:setopt('socket', 'sndtimeo', 1)  -- 发送 1 秒超时
  if not request:connect(auth_host:match('^[^:]+'), auth_host:match(':([%d]+)$') or 80) then
    request:close()
    api.log('认证：无法连接到认证服务器')
    return false
  end
  request:setopt('socket', 'rcvtimeo', 1)  -- 接收 1 秒超时
  request:send(auth_request_content)
  local response = request:recv(1024)
  request:close()
  if not response or #response == 0 then
    api.log('认证：无法从认证服务器接收响应')
    return false
  end

  local server_msg = response:match('Server:(.+)$')
  if not server_msg or #server_msg == 0 then
    api.log('认证：无法从响应中获取有效信息')
    return false
  end

  local res, err = json.parse(server_msg)
  if not res then
    api.log('认证：无法解析响应中的有效信息（', err, '）：', server_msg)
    return false
  end

  -- 认证失败
  if res['result'] ~= 'success' then
    api.log('认证：失败，原因：', res['message'])

    -- TODO: 认证响应适配

    api.log('意料之外的认证响应：', api.trim_string(server_msg))
    return false
  end

  return true
end

local function test_and_auto_switch()
  -- 无法访问认证重定向地址，说明已经认证成功，也可能是校园网故障
  if not can_access_auth() then
    return
  end

  local current_account = uci:get(app_name, 'config', 'current_account')
  local new_account_name = get_possible_account_name(current_account)
  local new_account = uci:get_all(app_name, new_account_name)

  -- TODO
  if try_auth(new_account) then
    api.log('自动认证：切换到账号 ', new_account['remark'], ' (', new_account_name, ')')
    uci:set(app_name, 'config', 'current_account', new_account['.name'])
    uci:commit(app_name)
  end
end

local function start()
  local enabled = uci:get(app_name, 'config', 'enabled')
  if enabled ~= '1' then
    return
  end

  -- 检查间隔，一次运行只获取一次，该值变更后需要重新运行该脚本
  local interval = uci:get(app_name, 'config', 'network_detection_interval') or 5

  api.log('守护进程启动，网络检测间隔 ', interval, ' 秒')

  while true do
    if is_file_exists(LOCK_FILE) then
      nixio.nanosleep(6)
    else
      os.execute('touch ' .. LOCK_FILE)
      test_and_auto_switch()
      nixio.fs.remove(LOCK_FILE)
      nixio.nanosleep(interval)
    end
  end
end

---
--- 自清理，强制结束该脚本后，可通过 cleanup 参数再次调用该脚本。
--- 将会清理掉强制退出后可能残留的垃圾，为下一次正常运行做准备。
local function cleanup()
  nixio.fs.remove(LOCK_FILE)
end

if not arg or #arg < 1 or not arg[1] then
  start()
elseif arg[1] == 'get_possible_account' then
  print(get_possible_account_name(arg[2], arg[3]))
elseif arg[1] == 'cleanup' then
  cleanup()
elseif arg[1] == 'test' then
  print(try_auth(uci:get_all(app_name, get_possible_account_name())))
else
  start()
end
