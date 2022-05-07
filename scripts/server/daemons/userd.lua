-- userd.lua
-- Created by wugd
-- 负责玩家相关的功能模块

-- 声明模块名
USER_D = {}
setmetatable(USER_D, {__index = _G})
local _ENV = USER_D

local exp_user_file = "data/txt/exp_user.txt"
local exp_user_table = {}

--关机时判断玩家数据是否全部保存完毕
local is_all_save = false
local user_fields_list = {}
local BATCH_COUNT = 60

-- 创建弱引用表
local user_list = {}
setmetatable(user_list, { __mode = "v" })

-- 定义内部函数
local function check_save(user)
    local cur_time  = os.time()
    local last_time = user:query_temp("last_autosave_time")
    if not last_time then
        -- 未开始计时
        user:set_temp("last_autosave_time", cur_time)
        return
    end

    if cur_time - last_time >= USER_STEP_SAVE_TIME then
        -- 自动保存玩家数据
        user:save_all()
        user:set_temp("last_autosave_time", cur_time)
    end
end

-- 无操作暂离操作
local function no_operation(user)
    local last_operation_time = user:query_temp("last_operation_time")
    if not last_operation_time then
        last_operation_time = os.time()
        user:set_temp("last_operation_time", last_operation_time)
    end
    if last_operation_time and os.time() - last_operation_time >= NO_OPERATION_TIME then
        user:connection_lost()
    end
end



-- 玩家心跳回调
local function when_user_heartbeat(user)
    check_save(user)
    no_operation(user)
end


function login(agent, user_rid, user_dbase)
    ASSERT(user_rid == user_dbase["rid"])

    -- 创建玩家对象
    local user = create_user(user_dbase)
    user:accept_relay(agent)

end

-- 创建玩家
function create_user(dbase)
    local user = USER_TDCLS.new(dbase)
    user_list[#user_list + 1] = user
    return user
end

-- 冻结玩家记录的回调
local function hiberate_callback(info, ret, result_list)
    info.sql_count = (info.sql_count or 0) - 1
    if info.sql_count <= 0 then
        REDIS_D.run_publish(REDIS_ACCOUNT_END_HIBERNATE, info.account_rid or "")
    end

end

-- 冻结玩家记录
function hiberate(user, save_callback)
    local arg = {
        user          = user,
        user_rid      = user:get_rid(),
        account_rid   = user:query("account_rid"),
        save_callback = save_callback,
        sql_count     = 0,
    }
    
    REDIS_D.run_publish(REDIS_ACCOUNT_START_HIBERNATE, user:query("account_rid"))
    user:set_change_to_db(hiberate_callback, arg)
end

--玩家数据是否全部保存完毕
function get_is_all_save()
    return is_all_save
end

function get_user_list()
    local result = {}
    for _,v in ipairs(user_list) do
        if v.destructed ~= true then
            table.insert(result, v)
        end
    end
    return result
end

function is_in_user_fields(key)
    local fields = DATA_D.get_table_fields("user") or {}
    return fields[key]
end

-- 是否 当天首次登陆
function is_first_login(user)
    -- 只取年月日比较
    local today     = os.date("%Y%m%d")
    local last_day  = os.date("%Y%m%d", user:query("last_logout_time"))

    if today > last_day then
        return true
    else
        return false
    end
end

--关闭服务器时，保存玩家数据
function shutdown()

    local list = get_user_list()
    for _,v in pairs(list) do
        user_logout(v)
        return
    end

    is_all_save = true
end

function publish_user_attr_update(data)
    DATA_USERD.user_data_changed(data)
    REDIS_D.run_command("PUBLISH", REDIS_ROLE_ATTR_UPDATE, encode_json(data))
end

-- 玩家登出处理
function user_logout(user)
    if not is_object(user) then
        return
    end
    
    destruct_object(user)
end

--是否升级
local function is_level_up(user)
    local exp = user:query("exp")
    local lv = user:query("lv")

    if not exp_user_table[lv] then
        return
    end

    return exp >= exp_user_table[lv]
end

--玩家升级
function try_level_up(user)
    if not user:is_user() then
        return false
    end
    if is_level_up(user) then

        local org_lv = user:query("lv")
        local exp    = user:query("exp")
        local cur_lv = org_lv

        --判断能升几级
        while exp >= exp_user_table[cur_lv] do
            exp = exp - exp_user_table[cur_lv]
            cur_lv = cur_lv + 1

            --到达满级清空经验值
            if  not exp_user_table[cur_lv] then
                exp = 0
                break
            end
        end
        
        local max_lv = ATTRIB_D.get_max_attrib(OB_TYPE_USER, "lv")
        if cur_lv > max_lv then
            cur_lv = max_lv
        end
        LOG_D.to_log(LOG_TYPE_LEVEL_UP, get_ob_rid(user), get_ob_rid(user), string.format("%d->%d", org_lv, cur_lv), "",LOG_CHANNEL_TEAM)
        user:set("lv", cur_lv)
        user:set("exp", exp)

        user:notify_fields_updated({"lv", "exp"})
        return true
    end
    return false
end

-- 加载玩家经验等级表
local function load_exp_user_table()
    local temp_exp_user_table = IMPORT_D.readcsv_to_mapping(exp_user_file)

    -- 获取最大经验
    for level, table in ipairs(temp_exp_user_table) do
          exp_user_table[level] = table.exp
    end
end


local function init()
end

local function event_new_day()
    local online_list = get_user_list()
    for _, user in pairs(online_list) do
        -- 在线玩家新一天刷新次数数据
        user:send_message(MSG_NEW_DAY, {})
    end
end

-- 模块的入口执行
function create()
    load_exp_user_table()
    register_post_init(init)
    -- 注册玩家的心跳回调
    register_heartbeat("USER_TDCLS", when_user_heartbeat)
    register_as_audience("USER_D", {EVENT_EXP_CHANGE=try_level_up})
end

create()