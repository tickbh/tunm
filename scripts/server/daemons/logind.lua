-- logind.lua
-- Created by wugd
-- 负责登录相关功能模块

-- 声明模块名
LOGIN_D = {}
setmetatable(LOGIN_D, {__index = _G})
local _ENV = LOGIN_D

local private_key = "wugd"
-- 登录的 token 有效时间
LOGIN_FLAG_TIMEOUT = 3600 * 24

-- 等待登陆的列表
local wait_login_list = {}

-- 定义内部接口，按照字母顺序排序
local function check_account_callback(login_info, ret, result_list)
    local agent = login_info["agent"]
    if type(result_list) ~= "table" or #result_list == 0 then
        -- trace("create new ACCOUNT_D!! ret = %o, result_list is = %o", ret, result_list)
        -- 创建新角色
        ACCOUNT_D.create_new_account(login_info)
        return
    end

    local data = result_list[1]
    if login_info.password ~= data.password then
        LOG_D.to_log(LOG_TYPE_LOGIN_FAIL, login_info["account"], "密码不正确", login_info.password, "")
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="用户或密码不正确", ret=-1})
        agent:connection_lost(true)
        return
    end

    local rid = data["rid"]
    local device_id = login_info["device_id"]
    -- 若传入 rid，则判断本服务器上是否存在该玩家对象
    -- if sizeof(rid) > 0 then
    --     local account_ob = find_object_by_rid(rid)
    --     if is_object(account_ob) then
    --         if account_ob:query("device_id") ~= device_id then
    --             trace("玩家(%o)登录传入的设备ID(%o)与内存中的玩家设备ID(%o)不符。\n",
    --                    account_ob, device_id, account_ob:query("device_id"))
    --             wait_account_login(agent, data["rid"], data)
    --         else
    --             account_ob:accept_relay(agent)
    --             account_ob:send_message(MSG_LOGIN_NOTIFY_STATUS, {ret=0})
    --             ACCOUNT_D.success_login(account_ob, true)
    --         end
    --         return
    --     end
    -- end

    if ACCOUNT_D.is_account_wait(data["rid"]) then
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="您的账号在别处请求登陆，请稍后", ret=-1})
        agent:connection_lost(true)
        return
    end

    if ACCOUNT_D.is_account_online(data["rid"]) then
        wait_account_login(agent, data["rid"], data)
        return
    end

    do_login(agent, data["rid"], data)
end

function do_login(agent, account_rid, info)
    IS_LOGIN_QUEUE_OPEN = true
    if IS_LOGIN_QUEUE_OPEN then
        -- 执行登录排队处理
        LOGIN_QUEUE_D.cache_login(agent, account_rid, info, ACCOUNT_D.login)
    else
        -- 调用模块进行登录处理
        ACCOUNT_D.login(agent, account_rid, info)
    end
end

function wait_account_login(agent, account_rid, info)
    REDIS_D.run_publish(REDIS_NOTIFY_ACCOUNT_OBJECT_DESTRUCT, account_rid)
    REDIS_D.run_publish(REDIS_ACCOUNT_WAIT_LOGIN, account_rid)

    wait_login_list[account_rid] = {
        agent = agent,
        account_rid = account_rid,
        info = info,
        time = os.time(),
    }
end

-- 玩家登录验证
function login_auth(agent, login_info)
    local device_id = login_info["device_id"]
    local auth_str  = login_info["auth_str"]

    if not login_info["timestamp"] then
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="会话验证失败，建议重新登陆 -1", ret=-1})
        agent:connection_lost(true)
        return false
    end
    
    if not login_info["password"] then
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="未输入密码", ret=-1})
        agent:connection_lost(true)
        return false
    end

    local curSecond = os.time()
    if login_info["timestamp"] < (curSecond- LOGIN_FLAG_TIMEOUT)
        or login_info["timestamp"] > (curSecond+ LOGIN_FLAG_TIMEOUT) then
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="会话已过期，建议重新登陆", ret=-2})
        agent:connection_lost(true)
        return false
    end

    return true
end

-- 玩家登录
function login(agent, login_info)
    --account case insensitive
    login_info["account"] = string.lower(login_info["account"] or "")
    local account   = login_info["account"]
    local password  = login_info["password"]    
    local version   = login_info["version"]
    local server_id   = login_info["server_id"]
    local device_id = login_info["device_id"]

    if not device_id then
        trace("玩家(%s ,设备%o)登录没有传入设备ID.", account, device_id)
        return
    end

    if not server_id then
        trace("玩家(%s ,设备%o)登录没有传入服务器ID.", account, device_id)
        return
    end

    local vaild, info = check_table_sql_vailed(login_info, {"account", "device_id", "password", "version", "server_id"})
    if not vaild then
        LOG.err("account:%o login contain unvaid char:%o", account, info)
        LOG_D.to_log(LOG_TYPE_LOGIN_FAIL, login_info["account"], "含有非法字符", "", "")
        agent:connection_lost(true)
        return
    end


    if (version or 0) < tonumber(VERSION) then
        LOG_D.to_log(LOG_TYPE_LOGIN_FAIL, login_info["account"], "版本过低", tostring(version or 0), "")
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="版本号过低，无法登陆", ret=-2})
        agent:connection_lost(true)
        return
    end

    if not login_auth(agent, login_info) then
        LOG_D.to_log(LOG_TYPE_LOGIN_FAIL, login_info["account"], "登陆验证失败", "", "")
        return
    end

    login_info["agent"] = agent
    local sql = SQL_D.select_sql("account", {_FIELDS={"account", "device_id", "rid", "name", "password", "is_freezed"}, _WHERE={account=account}})
    DB_D.read_db("account", sql, check_account_callback, login_info)
end

local function check_account_login(account_rid)
    if ACCOUNT_D.is_account_freeze(account_rid) or ACCOUNT_D.is_account_online(account_rid) then
        return
    end
    local wait_info = remove_get(wait_login_list, account_rid)
    if not wait_info then
        return
    end
    if not is_object(wait_info.agent) then
        REDIS_D.run_publish(REDIS_ACCOUNT_CANCEL_WAIT_LOGIN, wait_info.account_rid)
        return
    end
    do_login(wait_info.agent, wait_info.account_rid, wait_info.info)

end

local function time_handle()
    local need_op = {}
    for rid,info in pairs(wait_login_list) do
        if os.time() - info.time > 15 then
            need_op[rid] = true
        end
    end

    for rid,_ in pairs(need_op) do
        local info = remove_get(wait_login_list, rid)
        REDIS_D.run_publish(REDIS_ACCOUNT_CANCEL_WAIT_LOGIN, info.account_rid)
        if is_object(info.agent) then
            info.agent:connection_lost()
            return
        end
    end
end

-- 模块的入口执行
function create()
    register_as_audience("LOGIN_D", { EVENT_SUCCESS_ACCOUNT_OBJECT_DESTRUCT = check_account_login })
    register_as_audience("LOGIN_D", { EVENT_SUCCESS_ACCOUNT_END_HIBERNATE = check_account_login })

    set_timer(10000, time_handle, nil, true)
end

create()
