-- med.lua
-- Created by wugd
-- 登录相关模块

-- 声明模块名
ME_D = {}
setmetatable(ME_D, {__index = _G})
local _ENV = ME_D

local me_rid
local me_agent
local request = nil
local _enter_game = false

-- 进入游戏第一次更新玩家数据
function me_updated(agent, data)
    local item_list = remove_get(data, "item_list") or {}
    local equip_list = remove_get(data, "equip_list") or {}
    -- 创建玩家
    local user = PLAYER_TDCLS.new(data.user)
    for k, v in pairs(agent.data) do
        user:set_temp(k, v)
    end
    -- 关联玩家对象与连接对象
    user:accept_relay(agent)
    for _,v in ipairs(item_list) do
        local obj = PROPERTY_D.clone_object_from(v.class_id, v)
        user:load_property(obj)
    end

    for _,v in ipairs(equip_list) do
        local obj = PROPERTY_D.clone_object_from(v.class_id, v)
        user:load_property(obj)
    end

    -- 设置玩家心跳
    user:set_heartbeat_interval(HEARTBEAT_INTERVAL)
    raise_issue(EVENT_LOGIN_OK, user)

    me_rid = get_ob_rid(user)
    me_agent = user
end

function get_rid()
    return me_rid
end

function get_user()
    return (find_object_by_rid(me_rid))
end

function get_agent()
    if not is_object(me_agent) then
        me_agent = nil
        _enter_game = false
    end
    return me_agent
end

function close_agent()
    if is_object(me_agent) then
        me_agent:connection_lost()
        me_agent = nil
    end
end

function set_agent(agent)
    if not START_STREE_TEST then
        close_agent()
    end
    me_agent = agent
end

function clear_request_message()
    request = nil
end

function try_request_message()
    local agent = get_agent()
    if request ~= nil and agent ~= nil then
        agent:send_message(unpack(request))
        request = nil
    end
end

function request_message(...)
    local agent = get_agent()
    if agent ~= nil then
        if is_enter_game() then
            agent:send_message(...)
        else
            request = { ... }    
        end
    else
        request = { ... }
        --LOGIN_D.login()
    end
end

function is_enter_game()
    return _enter_game and get_agent() ~= nil
end

function set_enter_game(value)
    _enter_game = value
end

-- 模块的入口执行
function create()
end

create()
