-- data_userd.lua
-- Created by wugd
-- 负责缓存数据相关的功能模块

-- 声明模块名
module("DATA_USERD", package.seeall)

--缓存角色 rid，名字，竞技场区，战力，战斗详细数据
user_rid_data = {}
user_name_data = {}

--自动玩家的数据，若没有则自动生成
auto_user_rid_data = {}

local function callback_load_user_data(startPos, ret, result_list)
    assert(ret == 0, "load user data failed")
    for _,value in ipairs(result_list) do
        user_rid_data[value.rid] = value
        user_name_data[value.name] = value
    end
    if #result_list == 10000 then
        load_user_data_from_db(startPos + 10000)
    else
        finish_one_load_data()
    end
end

function user_info_change(rid, data)
    local value = user_rid_data[rid]
    merge(value, data)
end

function load_user_data_from_db(startPos)    
    startPos = startPos or 0    
    local sql = SQL_D.select_sql("user", {_FIELDS= {"rid", "name", "ban_flag", "lv", "vip", "last_login_time", "last_logout_time"}, 
        _LIMIT=10000, _OFFSET=startPos } )
    DB_D.read_db("user", sql, callback_load_user_data, startPos)
end

function user_data_changed(info)
    trace("user_data_changed is %o", info)
    local rid = remove_get(info, "rid")
    if not rid then
        return
    end
    local data = get_data_by_rid( rid )
    if not data then
        data = dup(info)
        user_rid_data[rid] = info
    end
    if info.name then
        user_name_data[data.name] = nil
        user_name_data[info.name] = data
    end
    merge(data, info)
end

function is_rid_online(rid)
    local data = user_rid_data[rid]
    return data and data.online == 1
end

function get_data_by_rid(rid)
    return user_rid_data[rid]
end

function get_data_by_name(name)
    return user_name_data[name]
end

function get_name_by_rid(rid)
    local data = get_data_by_rid(rid) or {}
    return data.name
end

function get_rid_by_name(name)
    local data = get_data_by_name(name) or {}
    return data.rid
end

function get_user_rid_data()
    return user_rid_data
end

local function create()
    load_user_data_from_db()
end

create()