--roomd.lua
--Created by wugd
--负责房间相关的功能模块

--创建模块声明
module("ROOM_D",package.seeall)

--场景列表
local room_list  = {}
local room_table = {}

local freq_table = {}

--定义内部接口，按照字母顺序排序
local function clear_doing_enter_room(entity)
    if entity:is_user() then
        entity:delete_temp("doing_enter_room")
    end
end

--定义公共接口，按照字母顺序排序

-- 广播消息
function broadcast_message(room_name, msg, ...)
    -- 取得该房间编号对应的房间对象
    local room = room_list[room_name]
    if not room then
        return
    end

    -- 广播消息
    room:broadcast_message(msg, ...)
end

--创建全部场景
function create_allroom(filename)
    room_table = IMPORT_D.readcsv_to_tables(filename)
    for k, v in pairs(room_table) do
        create_room(v)
    end
end

-- 获取csv表信息
function get_room_table()
    return room_table
end

--创建一个场景
function create_room(roomdata)
    local room_class = _G[roomdata.room_class]
    assert(room_class ~= nil, "场景配置必须存在")
    local room = clone_object(room_class, roomdata)
    trace("room name = %o", room:get_room_name())
    trace("room name = %o", room:get_func_list("get_room_name"))
    local room = DDZ_ROOM_CLASS.new(roomdata)
    trace("room name = %o", room:get_room_name())
    room_list[room:get_room_name()] = room

    return room
end

function enter_room(entity, room_name)
    
end

--获取房间对象
function get_room_list()
    return room_list
end

function get_room(room_name)
    return room_list[room_name]
end

--离开一个场景
function leave_room(entity, room_name)
    local room = room_list[room_name]

    if room then
        room:entity_leave(entity)
    end

    -- 删除玩家的位置信息
    entity:delete_temp("room")
end

-- 根据rid获取room_name
function get_room_name_by_rid(rid)
    local rid_ob = find_object_by_rid(rid)
    if not is_object(rid_ob) then
        return
    end
    return (rid_ob:query_temp("room"))
end

-- 获取某个房间玩家列表
function get_room_entity_list(room_name)
    local peo_list = {}
    local room = room_list[room_name]
    if room then
        local room_peoples = room:get_room_entity()
        local user
        local find_object_by_rid = find_object_by_rid
        local name, account, result
        local query_func
        for rid, info in pairs(room_peoples) do

            if info.ob_type == OB_TYPE_USER then
                user = find_object_by_rid(rid)
                if is_object(user) then
                    if not query_func then
                        query_func = user.query
                    end

                    name    = query_func(user, "name")
                    account = query_func(user, "account")
                    level   = query_func(user, "level")
                    result  = {
                        rid     = rid,
                        name = name,
                        account = account,
                        level = level
                    }

                    peo_list[#peo_list+1] = result
                else
                    room_peoples[rid] = nil
                end
            end
        end
    end

    return {
        ret         = #peo_list,
        result_list = peo_list,
    }
end

function update_room_entity(room_name, rid, pkg_info)

    local room = room_list[room_name]

    if not room then
        return
    end

    room:update_entity(rid, pkg_info)
end

-- 模块的入口执行
function create()
    -- create_allroom("data/txt/room.txt")
end

create()
