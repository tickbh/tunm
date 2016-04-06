-- user_dbd.lua
-- create by wugd
-- 缓存数据获取，一切非自己的数据取皆为异步
module("USER_DBD", package.seeall)

cookie_map = {}

local function check_finish(data)
    if not data.failed then
        if data.readnum > 0  then
            return
        end
        if data.writenum and data.writenum > 0 then
            return
        end
    end

    local record = cookie_map[data.cookie]
    if not record then
        return
    end
    cookie_map[data.cookie] = nil
    record.callback(data, record.callback_arg)
end

local function write_callback( data, ret, result_list )
    data["writenum"] = data["writenum"] - 1
    if ret ~= 0 then
        data.failed = true
    end
    check_finish(data)
end

local function accout_user_callback(data, ret, result_list)
    data["readnum"] = data["readnum"] - 1
    if type(result_list) ~= "table" or #result_list == 0 then
        data.failed = true
    else
        data["user"] = result_list[1]
    end
    check_finish(data)
end

local function item_callback(data, ret, result_list)
    data["readnum"] = data["readnum"] - 1
    if type(result_list) ~= "table" or ret ~= 0 then
        data.failed = true
    else
        data["item"] = result_list
    end
    check_finish(data)
end

local function equip_callback(data, ret, result_list)
    data["readnum"] = data["readnum"] - 1
    if type(result_list) ~= "table" or ret ~= 0 then
        data.failed = true
    else
        data["equip"] = result_list
    end
    check_finish(data)
end

function load_data_from_db(rid, callback, callback_arg)
    assert(callback ~= nil and type(callback) == "function", "callback must not empty")

    local table_list={
        {
            name = "user",    
            condition = {_WHERE={rid=rid} },
            callback = accout_user_callback
        },
        {
            name = "item",    
            condition = {_WHERE={owner=rid} },
            callback = item_callback
        },
        {
            name = "equip",    
            condition = {_WHERE={owner=rid} },
            callback = equip_callback
        }
    } 

    local num = sizeof(table_list)
    local data = { rid = rid, cookie = new_cookie(), readnum = num, is_db = true }
    local record = {
        callback     = callback,
        callback_arg = callback_arg,
    }
    cookie_map[data.cookie] = record

    for i=1, num do
        if table_list[i].name and table_list[i].condition and table_list[i].callback then
            local sql = SQL_D.select_sql(table_list[i].name, table_list[i].condition )
            DB_D.read_db(table_list[i].name , sql, table_list[i].callback, data)   
        end
    end

end