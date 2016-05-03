-- stress_testd.lua
-- Created by wugd
-- 压力测试

--[[ 压力测试模块 使用说明：
-- 接口：start
-- 例子：STRESS_TEST_D.start(50, "CHAT,ADD_ITEM")表示新登陆50个玩家，并开始"CHAT","ADD_ITEM"子模块的压力测试
-- 接口：stop
-- 例子：STRESS_TEST_D.stop("CHAT,ADD_ITEM")表示停止所有在线玩家的"CHAT","ADD_ITEM"子模块的压力测试
--]]

--声明模块
STRESS_TEST_D = {}
setmetatable(STRESS_TEST_D, {__index = _G})
local _ENV = STRESS_TEST_D

-- console是否繁忙标识
local is_system_busy          = false

-- 模块加载时间(起始时间供账号命名用)
local start_time              = 0

-- 尝试登陆的玩家数(玩家编号最大值，防止重新调用login出错)
local login_number            = 0

MAX_MEMCORY = 1024
TIME_LOGIN = 500


-- 调试函数，看本模块的局部变量值
function watch()
    print("账号前缀:%o\n", start_time)
end

-- 获取当前进程所占内存
function get_memory()
    local memory = memory_use() / 1024
    -- (MB)
    return memory
end

-- 检查系统是否繁忙
function check_system()

    -- 获取系统资源占用率
    local memory  = get_memory()

    -- 在线人数
    local online_number = online_number()

    -- 打印信息
    trace("\nprocess memory : %o MB\nlogin  number  : %o\nonline number  : %o\n",
           memory, login_number, online_number)

    -- 判断系统资源占用是否过多
    if memory > MAX_MEMCORY then

        -- 系统繁忙
        is_system_busy = true

        print("Console is Busy!! rest for a while..")

    else
        -- 系统空闲
        is_system_busy = false

        trace("Console is Working...")
    end
end

-- 计算当前在线人数
function online_number()

    local player_list = child_objects(PLAYER_TDCLS)

    return (sizeof(player_list))
end

-- 玩家心跳函数(负责玩家所有测试子模块的操作)
function heartbeat_handler(player)
    -- 如果console进程繁忙，则跳过
    if is_system_busy then
        return 
    end

    -- 玩家已析构
    if not is_object(player) then
        return 
    end

    -- 每个玩家的子模块的时间间隔
    local interval = player:query("interval")

    if not interval then
        return 
    end

    -- 每个玩家的子模块的累计时间
    local accumulate = player:query("accumulate") or {}

    -- 每个玩家需要测试的子模块
    local test_modules = player:query("test_modules") or {}

    -- 循环执行需要测试的子模块
    for test_module, _ in pairs(test_modules) do

        if interval[test_module] then
            -- 初始化累加时间
            if not accumulate[test_module] then
                accumulate[test_module] = 0
            end

            -- 累加时间
            accumulate[test_module] = accumulate[test_module] + HEARTBEAT_INTERVAL

            -- 累计时间 >= 间隔时间，则执行子模块操作
            if accumulate[test_module] >= interval[test_module] then

                local child_module = _G[test_module]
                if child_module and type(child_module.operation) == "function" then
                    -- 调用子模块的统一接口
                    child_module.operation(player)
                else
                    print("找不到压力测试子模块(%o) 或者 该子模块未定义'operation'接口!\n", test_module)
                    test_modules[test_module] = nil
                end

                -- 累计时间清零，重新计算
                accumulate[test_module] = 0
            end
        else
            print("要求测试的压力子模块(%o)并未定义!\n", test_module)
            test_modules[test_module] = nil
        end
    end

    -- 保存累计时间
    player:set("accumulate", accumulate)
end

-- 批量登陆(number个玩家)
function login(arg)
    -- 统计登陆数
    login_number = login_number + 1
    arg.number   = arg.number - 1

    -- 构造账号名(命名规则 "时间戳_编号")
    local account = string.format("%d_%d", start_time, login_number)

    -- 登陆一个玩家
    LOGIN_D.login(account, "default_password", arg.extra_data)

    if arg.number > 0 then
        -- 间隔一段时间后再登陆下一玩家
        set_timer(TIME_LOGIN, login, arg)
    end
end

-- 批量登出(number个玩家)
function logout(number)
    -- 在线所有玩家
    local player_list = child_objects(PLAYER_TDCLS)

    for i, player in ipairs(player_list) do
        -- 析构玩家
        destruct_object(player)

        if number and i >= number then
            break
        end
    end
end

-- 手动设置操作开始
function start(number, modules_str)

    if number and number <= 0 then
        return
    end

    _G["_DEBUG"] = nil
    _G["START_STREE_TEST"] = true

    -- 要测试的子模块列表
    local test_modules = {}
    if modules_str then
        local temp = explode(string.gsub(modules_str, " ", ""), ",")
        for _, start_module in ipairs(temp) do
            test_modules[start_module] = true
        end
    end

    -- 有 则新登陆number玩家再进行操作
    if number then

        local arg = {
            number     = number,
            extra_data = {test_modules = test_modules}
        }
        login(arg)

    -- 没有 则对已登陆的玩家进行操作
    else
        local player_list = child_objects(PLAYER_TDCLS)
        for _, player in ipairs(player_list) do
            player:set("test_modules", test_modules)
        end
    end
end

-- 停止指定子模块的测试
function stop(modules_str)

    local player_list = child_objects(PLAYER_TDCLS)

    -- 停止所有子模块的测试
    if not modules_str then
        for _, player in ipairs(player_list) do
            player:set("test_modules", {})
        end
    -- 停止指定子模块的测试
    else
        local stop_modules = explode(string.gsub(modules_str, " ", ""), ",")
        for _, player in ipairs(player_list) do

            local test_modules = player:query("test_modules") or {}
            for _, stop_module in ipairs(stop_modules) do
                test_modules[stop_module] = nil
            end
        end
    end
end

-- 给player增加指定模块的测试
function add_module(player, modules_str)
    modules_str = modules_str or ""

    local start_modules = explode(string.gsub(modules_str, " ", ""), ",")
    local test_modules  = player:query("test_modules") or {}
    for _, start_module in ipairs(start_modules) do
        test_modules[start_module] = true
    end
    player:set("test_modules", test_modules)
end

-- 给player清除指定模块的测试
function del_module(player, modules_str)

    if not modules_str then
        player:set("test_modules", {})
    else
        local stop_modules = explode(string.gsub(modules_str, " ", ""), ",")
        local test_modules = player:query("test_modules") or {}
        for _, stop_module in ipairs(stop_modules) do
            test_modules[stop_module] = nil
        end
    end
end

-- 获取 子模块随机间隔时间
local function get_random_interval(test_modules)
    local interval = {};
    for child_name, _ in pairs(test_modules) do
        if _G[child_name] and _G[child_name].random_interval then
            interval[child_name] = _G[child_name].random_interval()
        end
    end
    return interval;
end

-- 登陆成功 事件处理
function func_login_ok(player)

    trace("%o登陆成功！\n", player)

    local extra_data   = player:query_temp("extra_data") or {}
    local test_modules = extra_data.test_modules

    if test_modules then
        -- 获取随机时间间隔
        local interval = get_random_interval(test_modules)

        -- 去除不存在的测试子模块
        for test_module, _ in pairs(test_modules) do
            if not interval[test_module] then
                test_modules[test_module] = nil
            end
        end

        -- 设置子模块的测试时间间隔、和需要测试的子模块
        player:set("interval", interval)
        player:set("test_modules", test_modules)
    end
end

-- 模块析构函数
function destruct()
    remove_audience_from_raiser("STRESS_TEST_D", {SF_LOGIN_OK})
end


local function init()
    -- 定时检测系统是否繁忙
    set_timer(100000, check_system, {}, true)

    -- watch()
end

-- 模块的入口执行
function create()

    -- 加载下属子目录
    load_folder("client/daemons/stress_test")

    -- 注册玩家心跳回调
    register_heartbeat("PLAYER_TDCLS", heartbeat_handler)

    -- 注册延迟调用回调
    register_post_init(init)

    -- 注册登陆成功事件 处理函数
    register_as_audience("STRESS_TEST_D", {EVENT_LOGIN_OK = func_login_ok})

    -- 记录模块加载时间(现在只取时间戳后几位)
    start_time = string.sub(tostring(os.time()), 8)
end

create()
