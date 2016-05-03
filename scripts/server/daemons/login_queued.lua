-- login_queued.lua
-- Created by wugd
-- 登录排队机制

-- 声明模块名
LOGIN_QUEUE_D = {}
setmetatable(LOGIN_QUEUE_D, {__index = _G})
local _ENV = LOGIN_QUEUE_D

-- 服务端负载
local online_limit = 600
local cpu_useage_limit = 85

-- 登录队列大小限制
local login_size_limit = 30

-- 需要执行登录的队列
local login_queue = {}

-- 正在登陆的玩家列表
local login_list = {}
setmetatable(login_list, { __mode = "v" })


-- 获得正在登陆的agent
local function get_login_list_size()
    local login_size = 0
    for _, agent in pairs(login_list) do
        if is_object(agent) then
            login_size = login_size + 1
        end
    end
    return login_size
end

local function _notify_queue_number()

    -- 弹出无效的登陆数据
    local login_data = login_queue:get_first()
    if login_data then
        if not login_data["agent"] or not login_data["agent"]:is_valid() or
            not login_data["agent"]:is_authed() then
            login_queue:pop_first()
        end
    end

    -- 通知客户端排队号数
    local agent
    local invalid = 0
    local index = 0
    for _,value in pairs(login_queue:get_data()) do
        if type(value) == "table" then
            index = index + 1
            agent = value["agent"]

            -- 统计无效的agent
            if not agent or not agent:is_valid() or not agent:is_authed() then
                invalid = invalid + 1
            end

            if agent and agent:is_valid() and agent:is_authed() then
                agent:send_message(MSG_WAIT_QUEUE_NUMBER,
                                (k - invalid + 1) + get_login_list_size())
            end
        end
    end
end

-- 处理登陆队列的登陆
local function _respond_login()

    if not is_server_load_limit() and get_login_list_size() <= login_size_limit then
        -- 将客户端请求出队列
        local login_data = login_queue:pop_first()
        if login_data then
            if login_data["agent"]:is_valid() and login_data["agent"]:is_authed()
                and type(login_data["func"]) == "function" then

                -- 设置agent为正在登陆的
                login_list[login_data["agent"]:get_uni_port_no()] = agent

                -- 执行登录处理
                login_data["func"](login_data["agent"], login_data["rid"], login_data["login_info"])
            end
        end
    end
end

-- 客户端登录请求缓存到队列
function cache_login(agent, rid, login_info, func)
    -- 判断连接是否有效
    if agent:is_valid() and agent:is_authed() then

        -- 登录信息
        local login_data = {
            agent = agent,
            rid = rid,
            login_info = login_info,
            func = func,
        }

        local is_vip = login_info["is_vip"]
        if is_vip == 1 then
            -- 如果是vip且服务端不繁忙
            if not is_server_load_limit() then

                -- 设置agent为正在登陆的
                login_list[agent:get_uni_port_no()] = agent

                -- 执行登录处理
                func(agent, rid, login_info)
            else
                login_queue:push_front(login_data)
            end
        else

            -- 判断正在登录的请求是否小于登陆限制
            if get_login_list_size() <= login_size_limit then

                if not is_server_load_limit() then

                    -- 设置agent为正在登陆的
                    login_list[agent:get_uni_port_no()] = agent

                    -- 执行登录处理
                    func(agent, rid, login_info)
                else
                    login_queue:push_back(login_data)
                end
            else
                login_queue:push_back(login_data)
            end
        end
    end
end

-- 移除正在登陆的agent
function remove_login_list_agent(port_no)
    login_list[port_no] = nil
end

-- 是否处于服务器负载
function is_server_load_limit()

    -- 判断gs负载情况
    local cpu = SYSTEM_D.get_cpu_ratio_avg() or 0
    if cpu < cpu_useage_limit then
        return false
    end

    return true
end

-- 从登录队列中取出登录请求
function respond_login()

    _respond_login()

    --每隔500ms, 从相应登录请求
    set_timer(500, _respond_login, nil, true)
end

-- 提示排队的数量
function notify_queue_number()

    _notify_queue_number()

    --每隔6000ms, 从相应登录请求
    set_timer(6000, _notify_queue_number, nil, true)
end

function get_online_limit()
    return online_limit
end

function set_online_limit(num)

    if not is_int(num) then
        trace("%o不为数字", num)
        return
    end

    online_limit = num
end


-- 登陆成功 事件处理
local function func_login_ok(user)
    remove_login_list_agent(user:get_uni_port_no())
end

-- 模块的入口执行
function create()
    -- 初始化登录队列
    login_queue = clone_object(QUEUE_TDCLS)

    -- 响应gs队列中的登录请求
    register_post_init(respond_login)

    -- 提示排队的数量
    register_post_init(notify_queue_number)

    register_as_audience("LOGIN_QUEUE_D", {EVENT_USER_LOGIN = func_login_ok})
end

create()
