-- raiser.lua
-- Created by wugd
-- 实现事件相关功能

--变量定义
-- event_responder 和 event_audience 格式如下：
-- {
--                 EVENT_XXX : {
--                       listener = {"func" : func, args = args},
--                       ...
--                 },
--                 ...
-- }

--raiser发起事件的类
--listener 接收的对像 仅做避免重复的索引用
--event_routines 事件的索引
local event_responder = {};
local event_audience  = {};

-- 定义公共接口，按照字母顺序排序
function get_all_audiences()
    return event_audience;
end

function get_all_responders()
    return event_responder;
end

-- 发送事件
function raise_issue(event, ...)
    local info, f, result, ret = nil, nil, {}, nil
    local nodes = event_responder[event] or {}
    for listener, node in pairs(nodes) do
        f = node["func"];
        if type(f) == "function" then
            ret = call_func(f, node["args"], ...)
            if ret then
                table.insert(result, ret)
                return result
            end
       end
    end

    local nodes = event_audience[event] or {}
    for listener, node in pairs(nodes) do
        f = node["func"];
        if type(f) == "function" then
            ret = call_func(f, node["args"], ...)
            if ret then
                table.insert(result, ret)
            end
       end
    end

    return result
end

local function register_by_type(event_struct, listener, event_routines)
    -- 遍历注册的事件
    for event, info in pairs(event_routines) do
        local func = info
        local args = {}
        if type(func) ~= "function" then
            func = info["func"]
            args = info["args"]
        end
        assert(type(func) == "function")
        event_struct[event] = event_struct[event] or {}
        event_struct[event][listener] = {func = func, args = args}
    end
end

-- 注册观众
-- 接收指定事件，但不拦截该事件，事件会继续传递给其它观众
function register_as_audience(listener, event_routines)
    register_by_type(event_audience, listener, event_routines)
end

-- 注册响应者
-- 指定事件若被响应者截获，则会直接返回，不会继续传递该事件
function register_as_responder(listener, event_routines)
    register_by_type(event_responder, listener, event_routines)
end

local function remove_by_type(event_struct, listener, events)
    assert(listener ~= nil, "listener must no nil")
    if not events then
        for event,node in pairs(event_struct) do
            node[listener] = nil
        end
        return
    end

    for _, event in ipairs(events) do
        if event_struct[event] then
            event_struct[event][listener] = nil
        end
    end
end

-- 移除观众
function remove_audience_from_raiser(listener, events)
    remove_by_type(event_audience, listener, events)
end

-- 移除响应者
function remove_responder_from_raiser(listener, events)
    remove_by_type(event_responder, listener, events)
end

