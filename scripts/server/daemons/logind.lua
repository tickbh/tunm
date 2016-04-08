-- logind.lua
-- Created by wugd
-- 负责登录相关功能模块

-- 声明模块名
module("LOGIN_D", package.seeall);

local private_key = "wugd";
-- 登录的 token 有效时间
LOGIN_FLAG_TIMEOUT = 3600 * 24  

-- 定义内部接口，按照字母顺序排序

local function check_account_callback(login_info, ret, result_list)
    if type(result_list) ~= "table" or #result_list == 0 then
        trace("create new ACCOUNT_D!! ret = %o, result_list is = %o", ret, result_list)
        -- 创建新角色
        ACCOUNT_D.create_new_account(login_info);
        return;
    end

    local data = result_list[1]
    if login_info.password ~= data.password then
        LOG_D.to_log(LOG_TYPE_LOGIN_FAIL, login_info["account"], "密码不正确", login_info.password, "")
        agent:send_message(MSG_LOGIN_NOTIFY_STATUS, {err_msg="用户或密码不正确", ret=-1})
        agent:connection_lost(true)
        return
    end

    local rid = data["rid"]
    -- 若传入 rid，则判断本服务器上是否存在该玩家对象
    if sizeof(rid) > 0 then
        local account_ob = find_object_by_rid(rid);
        if is_object(account_ob) then
            if account_ob:query("device_id") ~= device_id then
                trace("玩家(%o)登录传入的设备ID(%s)与内存中的玩家设备ID(%s)不符。\n",
                       account_ob, device_id, account_ob:query("device_id"));
                account_ob:connection_lost(true)
            else
                account_ob:accept_relay(login_info["agent"]);
                account_ob:send_message(MSG_LOGIN_NOTIFY_STATUS, {ret=0})
                ACCOUNT_D.success_login(account_ob, true)
                return;
            end
        end
    end
    
    -- -- 旧角色登录
    ACCOUNT_D.login(login_info["agent"], data["rid"], result_list[1]);
end

-- 玩家登录验证
function login_auth(agent, login_info)
    local device_id = login_info["device_id"];
    local auth_str  = login_info["auth_str"];

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

    return true;
end

-- 玩家登录
function login(agent, login_info)
    --account case insensitive
    login_info["account"] = string.lower(login_info["account"] or "")
    local account   = login_info["account"];
    local password  = login_info["password"];    
    local version   = login_info["version"];
    local server_id   = login_info["server_id"];
    local device_id = login_info["device_id"];

    if not device_id then
        trace("玩家(%s ,设备%o)登录没有传入设备ID.\n", account, device_id)
        return;
    end

    if not server_id then
        trace("玩家(%s ,设备%o)登录没有传入服务器ID.\n", account, device_id)
        return;
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
        return;
    end

    login_info["agent"] = agent;
    local sql = SQL_D.select_sql("account", {_FIELDS={"account", "device_id", "rid", "name", "password", "is_freezed"}, _WHERE={account=account}})
    DB_D.read_db("account", sql, check_account_callback, login_info)
end

-- 模块的入口执行
function create()
end

create();
