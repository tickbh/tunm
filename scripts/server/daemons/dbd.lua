-- dbd.lua
-- Created by wugd
-- 数据库相关功能

-- 声明模块名
DB_D = {}
setmetatable(DB_D, {__index = _G})
local _ENV = DB_D

-- 宏定义
local TIMEOUT = 15

-- 内部变量声明
local cookie_map = {}
local db_type

-- 定义内部接口，按照字母顺序排序

-- 定时处理函数
local function timer_handle(para)
    local cur_time = os.time()

    -- 遍历 cookie_map，将超时的请求移除
    for k,v in pairs(cookie_map) do
        if v["begin_time"] + TIMEOUT <= cur_time then
            -- 超时，需要移除

            -- 若存在回调，则调用之
            local callback, arg = v["callback"], v["callback_arg"]
            cookie_map[k] = nil
            if type(callback) == "function" then
                if arg then
                    -- -2 表示超时
                    callback(arg, -2)
                else
                    callback(-2)
                end
            end
        end
    end
end

-- 默认回调函数
local function default_callback(sql_cmd, ret, result_list)
    TRACE("default_callback sql_cmd(%o) failed. error : '%o'", sql_cmd, ret)
end

-- 定义公共接口，按照字母顺序排序

-- 取得 auto_increment 类型 key 的构造描述符
function get_auto_increment_desc()
    if get_db_type() == "sqlite" then
        -- sqlite 语法
        return "INTEGER PRIMARY KEY "
    else
        -- mysql 语法
        return "INTEGER PRIMARY KEY NOT NULL AUTO_INCREMENT "
    end
end

function get_db_type()
    -- if true then
    --     return "mysql"
    -- end
    if DB_TYPE then
        return DB_TYPE
    end

    db_type = get_config_value("DB_TYPE")
    if sizeof(db_type) == 0 and STANDALONE then
        db_type = "sqlite"
    end

    return db_type
end

function is_sqlite()
    return get_db_type() == "sqlite"
end


function get_db_index()
    local dt = get_db_type()
    if dt == "mysql" then
        return 1
    end
    return 0
end

function lua_sync_insert(db_name, sql_cmd, n_dbtype)
    -- TRACE("lua_sync_insert sql is %o ", sql_cmd)
    n_dbtype = n_dbtype or get_db_index()
    local err, ret = db_insert_sync(db_name, sql_cmd, n_dbtype)
    return err, ret
end

function lua_sync_select(db_name, sql_cmd, n_dbtype)
    TRACE("lua_sync_select sql is %o ", sql_cmd)
    n_dbtype = n_dbtype or get_db_index()
    local err, ret = db_select_sync(db_name, n_dbtype, sql_cmd)
    TRACE("lua_sync_select err, ret %o %o ", err, ret)
    if err ~= 0 then
        return err, ret
    end
    return err, ret
end

function convert_table_info(table_struct)
    local result = {}
    for _,value in ipairs(table_struct) do
        local convert = {}
        convert["field"] = value["COLUMN_NAME"] or value["name"] or ""
        convert["type"] = value["COLUMN_TYPE"] or value["type"] or ""
        convert["key"] = value["COLUMN_KEY"] or value["key"] or ""
        convert["default"] = value["COLUMN_DEFAULT"] or value["dflt_value"] or ""
        convert["extra"] = value["EXTRA"] or ""
        convert["nullable"] = value["IS_NULLABLE"] == "NO" and 0 or 1
        if get_db_type() == "sqlite" then
            convert["nullable"] = value["notnull"] == 1 and 0 or 1
        end
        result[convert["field"]] = convert
    end
    return result
end

function convert_table_index(table_struct)
    local result = {}
    for _,value in ipairs(table_struct) do
        local convert = {}
        convert["table"] = value["TABLE_NAME"] or ""
        convert["name"] = value["INDEX_NAME"] or ""
        convert["indexs"] = value["COLUMN_NAME"] or ""
        convert["uni"] = tonumber(value["NON_UNIQUE"]) == 0
        result[convert["name"]] = convert
    end
    return result
end

-- 取得指定表的表结构信息
function get_table(table_name, db_name)
    -- 取得该表所在的 db
    db_name = db_name or DATA_D.get_db_name(table_name)
    if not db_name then
        return
    end

    -- 构造查询语句
    local sql_cmd
    local n_dbtype = 0
    if get_db_type() == "sqlite" then
        sql_cmd = string.format("pragma table_info (%s)", table_name)
    else
        n_dbtype = 1
        sql_cmd = string.format("describe %s", table_name)
    end

    -- 同步执行数据库操作
    local err, ret = lua_sync_select(db_name, sql_cmd, n_dbtype)
    return ret
end

function get_index_table(table_name, db_name)
    -- 取得该表所在的 db
    db_name = db_name or DATA_D.get_db_name(table_name)
    if not db_name then
        return
    end

    -- 构造查询语句
    local sql_cmd
    local n_dbtype = 0
    if get_db_type() == "sqlite" then
        sql_cmd = string.format("pragma table_info (%s)", table_name)
    else
        n_dbtype = 1
        sql_cmd = string.format("SHOW INDEX FROM %s", table_name)
    end

    -- 同步执行数据库操作
    local err, ret = lua_sync_select(db_name, sql_cmd, n_dbtype)
    return ret
end

--判断cookie_map是否为空
function is_cookie_map_nil()
    if sizeof(cookie_map) == 0 then
        return true
    end
    return false
end

-- 通知操作结果
function notify_operation_result(cookie, ret, result_list)
    -- 若不在 cookie_map 中，则认为该通知非法
    local oper = cookie_map[tostring(cookie)]
    if not oper then
        do return end
    end

    -- 从 cookie_map 中移除该操作记录
    cookie_map[tostring(cookie)] = nil

    -- 取得该操作的回调函数
    local callback     = oper["callback"]
    local callback_arg = oper["callback_arg"]
    local sql_cmd      = oper["sql_cmd"]

    -- 若存在回调，则调用之，否则调用默认回调函数
    if type(callback) == "function" then

        -- 若有结果集
        if callback_arg then
            callback(callback_arg, ret, result_list)
        else
            callback(ret, result_list)
        end
    else
        default_callback(sql_cmd, ret, result_list)
    end
end

-- 读取数据库数据
function read_db(table_name, sql_cmd, callback, callback_arg)
    local db_name = DATA_D.get_db_name(table_name)
    local cookie = 0
    if callback then
        cookie = new_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         sql_cmd      = sql_cmd,
                         begin_time   = os.time(),
        }
        cookie_map[tostring(cookie)] = record
    end

    local n_dbtype = 0
    if get_db_type() == "mysql" then
        n_dbtype = 1
    end

    -- 执行数据库操作
    db_select(db_name, n_dbtype, sql_cmd, cookie)
end

-- 执行事务
function transaction_db(table_name, sql_cmd_list, callback, callback_arg)
    local db_name = DATA_D.get_db_name(table_name)
    local cookie = 0
    if callback then
        cookie = new_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         sql_cmd      = sql_cmd_list,
                         begin_time   = os.time(),
        }
        cookie_map[tostring(cookie)] = record
    end

    local n_dbtype = 0
    if get_db_type() == "mysql" then
        n_dbtype = 1
    end

    -- 执行数据库操作
    db_transaction(db_name, n_dbtype, sql_cmd_list, cookie, 0)
end

-- 执行批量指令
-- 与 transaction 不同的是，该操作总是执行 commit，即使某条语句失败
function batch_execute_db(table_name, sql_cmd_list, callback, callback_arg)
    local db_name = DATA_D.get_db_name(table_name)
    local cookie = 0
    if callback then
        cookie = new_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         sql_cmd      = sql_cmd_list,
                         begin_time   = os.time(),
        }
        cookie_map[tostring(cookie)] = record
    end

    local n_dbtype = 0
    if get_db_type() == "mysql" then
        n_dbtype = 1
    end

    -- 执行数据库操作
    db_batch_execute(db_name, n_dbtype, sql_cmd_list, cookie, 0)
end

function sync_insert_db(table_name, sql_cmd)
    -- TRACE("sync_insert_db sql is %o ", sql_cmd)
    local db_name = DATA_D.get_db_name(table_name)
    return lua_sync_insert(db_name, sql_cmd)
end

-- 更新数据库操作
function insert_db(table_name, sql_cmd, callback, callback_arg)
    local db_name = DATA_D.get_db_name(table_name)
    local cookie = 0
    if callback then
        cookie = new_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         sql_cmd      = sql_cmd,
                         begin_time   = os.time(),
        }
        cookie_map[tostring(cookie)] = record
    end

    local n_dbtype = 0
    if get_db_type() == "mysql" then
        n_dbtype = 1
    end
    -- 执行数据库操作
    db_insert(db_name, n_dbtype, sql_cmd, cookie)
end

-- 更新数据库操作
function execute_db(table_name, sql_cmd, callback, callback_arg)
    local db_name = DATA_D.get_db_name(table_name)
    local cookie = 0
    if callback then
        cookie = new_cookie()
        local record = {
                         callback     = callback,
                         callback_arg = callback_arg,
                         sql_cmd      = sql_cmd,
                         begin_time   = os.time(),
        }
        cookie_map[tostring(cookie)] = record
    end

    local n_dbtype = 0
    if get_db_type() == "mysql" then
        n_dbtype = 1
    end
    -- 执行数据库操作
    db_execute(db_name, n_dbtype, sql_cmd, cookie)
end

function gen_cloumn_ext(cloumn)
    local sql = ""
    local has_default = false
    if cloumn["default"] and sizeof(cloumn["default"]) > 0 then
        sql = sql .. string.format(" DEFAULT '%s' ", cloumn["default"])
        has_default = true
    end
    if cloumn["nullable"] == 0 then
        sql = sql .. " NOT NULL "
        if not has_default and get_db_type() == "sqlite" then
            sql = sql .. " default ''"
        end
    end
    if get_db_type() ~= "sqlite" and cloumn["comment"] then
        sql = sql .. string.format(" COMMENT '%s'", cloumn["comment"])
    end
    return sql
end

function gen_cloumn_after(cloumn)
    local sql = ""
    if cloumn["pre_field"] and sizeof(cloumn["pre_field"]) > 0 then
        sql = sql .. string.format(" AFTER `%s` ", cloumn["pre_field"])
    end
    return sql
end


function gen_unique_ext(cloumn)
    if not cloumn["key"] then
        return ""
    end

    if cloumn["key"] == "NO_UNI" then
        return string.format(", DROP INDEX `%s`", cloumn["field"])
    end

    if cloumn["key"] == "UNI" then
        return string.format(", ADD UNIQUE (%s)", cloumn["field"])
    end
    return ""
end

function del_primary_key(db_name, table_name, key)
    if key == nil or sizeof(key) == 0 then
        return true
    end
    local sql = string.format("ALTER TABLE `%s` DROP PRIMARY KEY", table_name)
    return lua_sync_select(db_name, sql)
end

function add_primary_key(db_name, table_name, key)
    if key == nil or sizeof(key) == 0 then
        return true
    end
    local sql = string.format("ALTER TABLE `%s` ADD PRIMARY KEY (%s)", table_name, key)
    return lua_sync_select(db_name, sql)
end

function add_cloumn(db_name, table_name, cloumn)
    local sql = string.format("ALTER TABLE `%s` ADD COLUMN `%s` %s", table_name, cloumn["field"], cloumn["type"])
    sql = sql .. gen_cloumn_ext(cloumn)
    if get_db_type() ~= "sqlite" then
        sql = sql .. gen_cloumn_after(cloumn)
    end
    TRACE("add_cloumn sql is %o", sql)
    return lua_sync_select(db_name, sql)
end

function del_cloumn(db_name, table_name, cloumn)
    local sql = string.format("ALTER TABLE `%s` DROP COLUMN `%s`", table_name, cloumn["field"])
    TRACE("del_cloumn sql is %o", sql)
    return lua_sync_select(db_name, sql)
end

function mod_cloumn(db_name, table_name, cloumn)
    local sql = string.format("ALTER TABLE `%s` MODIFY COLUMN `%s` %s", table_name, cloumn["field"], cloumn["type"])
    sql = sql .. gen_cloumn_ext(cloumn)
    TRACE("mod_cloumn sql is %o", sql)
    return lua_sync_select(db_name, sql)
end

function add_index(db_name, table_name, index)
    local sql = string.format("ALTER TABLE `%s` ADD ", table_name)
    if index["uni"] then
        sql = sql .. " UNIQUE "
    end
    sql = sql .. string.format(" INDEX %s(%s)", index["name"], index["indexs"])
    return lua_sync_select(db_name, sql)
end

function get_cookie_map()
    return cookie_map
end

-- 模块的入口执行
function create()
    -- 每秒判断一次
    set_timer(1000, timer_handle, nil, true)
end

create()

