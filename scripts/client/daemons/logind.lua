-- logind.lua
-- Created by wugd
-- 登录相关模块

-- 声明模块名
LOGIN_D = {}
setmetatable(LOGIN_D, {__index = _G})
local _ENV = LOGIN_D

local private_key = "wugdGame"

local function connect_callback(agent, arg)
    if not is_object(agent) then
        trace("连接服务器失败.\n")
        return
    end

    ME_D.set_agent(agent)
    trace("----------------------success connected server-----------------------")

    -- 发送验证信息
    agent:send_message(CMD_INTERNAL_AUTH, 2, tostring(math.random(100000, 999999)), "")

    local account  = arg["account"]
    local password = arg["password"]
    local server_id = arg["server_id"] or 1

    local login_info = {}
    login_info["account"] = account
    login_info["device_id"] = arg["device_id"]
    --custom yourself auth func    
    login_info["password"] = calc_str_md5(password)
    login_info["server_id"] = server_id
    login_info["timestamp"] = os.time()
    login_info["version"] = 1

    -- 保存数据到agent
    for key, value in pairs(arg) do
        agent.data[key] = value;
    end

    -- 发送登录消息
    agent:send_message(CMD_LOGIN, login_info)
end

-- 登录建立连接的接口
function login(account, password, extra_data)
    if not START_STREE_TEST and ME_D.get_agent() then
        return
    end

    local ip, port = GATE_IP, tonumber(GATE_CLIENT_PORT)
    -- 建立连接
    local ret = socket_connect(ip, port, 10000, connect_callback, {
                    account  = account,
                    password = password,
                    extra_data = extra_data,
                    --custom yourself device id func
                    device_id = tostring(math.random(100000, 999999)),
                    server_id = 1,
                })
    if ret ~= 1 then
        -- 连接失败
        --play_font_tips(string.format("连接服务器(%o:%o)失败。\n", ip, port),3)
        trace("连接服务器(%o:%o)失败。\n", ip, port)
        return false
    end

    return true
end

-- 模块的入口执行
function create()
end

create()
