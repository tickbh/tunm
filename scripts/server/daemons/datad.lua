-- datad.lua
-- 分析数据库组成结构

-- 声明模块名
DATA_D = {}
setmetatable(DATA_D, {__index = _G})
local _ENV = DATA_D

-- 内部变量声明
local table_infos = {}
local db_infos = {}

local test_cloumn = "only_test_for_create"

function get_table_info(table_name) 
    return table_infos[table_name]
end

function get_table_fields( table_name )
    local tinfo = table_infos[table_name]
    if not tinfo then
        return {}
    end
    return tinfo["field_map"]
end

function is_field_exist(table_name, field)
    local fields = get_table_fields(table_name)
    return fields[field] ~= nil
end

local function create_db(db_name,tinfo)
    -- 创建表和相应的索引
    for _, sql_cmd in ipairs(tinfo["sql_cmds"]) do
        -- 替换自增长的定义字段
        sql_cmd = string.gsub(sql_cmd, "$AUTO_INCREMENT",
                                      DB_D.get_auto_increment_desc())
        DB_D.execute_db(db_name, sql_cmd)
    end
end

function ensure_database()
    for db_name, dinfo in pairs(db_infos) do
        ensure_exist_database(db_name)
    end

    for table_name, tinfo in pairs(table_infos) do
        ensure_exist_table(table_name, tinfo["db"])
        check_table_right(tinfo)
        check_table_index_right(tinfo)
    end
end

function get_db_name( table_name )
    local tinfo = table_infos[table_name]
    if not tinfo then
        return nil
    end
    return tinfo["db"]
end

function generate_field_map(tablejson, field_table)
    local result = {}
    for _ , value in ipairs(tablejson["fields"]) do
        if value["key"] ~= "index" then
            if value["key"] == "PRI" or value["key"] == "UNI" then
                value["nullable"] = 0
            end
            if field_table[value["field"]] then
                value["pre_field"] = field_table[value["field"]]
            end
            result[value["field"]] = value
        end
    end
    return result
end

function generate_index_map(tablejson)
    local result = {}
    for _ , value in ipairs(tablejson["fields"]) do
        if value["key"] == "index" then
            value = DUP(value)
            result[value["name"]] = value
        elseif value["key"] == "UNI" then
            value = DUP(value)
            value["name"] = value["field"]
            value["indexs"] = value["field"]
            value["uni"] = true
            result[value["name"]] = value
        elseif value["key"] == "PRI" then
            value = DUP(value)
            value["name"] = "PRIMARY"
            value["indexs"] = value["field"]
            result[value["name"]] = value
        end
    end
    return result
end

function load_database( path )
    local json_table = get_file_json(path)
    for database_name, tablearray in pairs(json_table) do
        database_name = database_name .. (DB_SUFFIX or "")
        db_infos[database_name] = db_infos[database_name] or {}

        for _,tablejson in ipairs(tablearray) do
            local pre_field = nil
            local field_order = {}
            local field_table = {}
            for _ , value in ipairs(tablejson["fields"]) do
                if value["field"] then
                    table.insert(field_order, value["field"])
                    field_table[value["field"]] = pre_field
                    pre_field = value["field"]
                end 
            end
            local table_value = tablejson
            table_value["db"] = database_name
            table_value["field_map"] = generate_field_map(tablejson, field_table)
            table_value["index_map"] = generate_index_map(tablejson)
            table_value["field_order"] = field_order
            table_infos[table_value["name"]] = table_value
            db_infos[database_name][table_value["name"]] = table_value
        end
    end
end

function is_database_exist(dbname)
    local sql = string.format("SHOW DATABASES LIKE '%s'", dbname)
    local err, ret = DB_D.lua_sync_select("", sql, DB_D.get_db_index())
    if err ~= 0 then
        return false
    end
    for _,value in ipairs(ret) do
        for k,v in pairs(value) do
            if v == dbname then
                return true
            end
        end
    end
    return false 
end

function ensure_exist_database(dbname)
    if DB_D.is_sqlite() or is_database_exist(dbname) then
        return true
    end
    local sql = string.format("CREATE DATABASE `%s`", dbname)
    local err, ret = DB_D.lua_sync_select("", sql, DB_D.get_db_index())
    return true
end

function is_table_exist(tablename, dbname)
    dbname = dbname or DATA_D.get_db_name(tablename)
    if dbname == nil then
        TRACE("unknow table %o in which db ", tablename)
        return false
    end
    local sql = string.format("SHOW TABLES LIKE '%s'", tablename)
    if DB_D.is_sqlite() then
        sql = string.format("select name from sqlite_master where type='table' and name = '%s'", tablename)
    end
    local err, ret = DB_D.lua_sync_select(dbname, sql, DB_D.get_db_index())
    TRACE("err ret = %o, %o", err, ret)
    if err ~= 0 then
        return false
    end
    for _,value in ipairs(ret) do
        for k,v in pairs(value) do
            if v == tablename then
                return true
            end
        end
    end
    return false
end

function ensure_exist_table(tablename, dbname)
    dbname = dbname or DATA_D.get_db_name(tablename)
    if dbname == nil then
        TRACE("unknow table %o in which db ", tablename)
        return false
    end

    if is_table_exist(tablename, dbname) then
        return true
    end
    local sql = string.format("CREATE TABLE `%s` (`%s` int)", tablename, test_cloumn)
    local err, ret = DB_D.lua_sync_select(dbname, sql, DB_D.get_db_index())
    return true
end

function get_pk(table_info)
    local pk = nil
    for field, value in pairs(table_info) do
        if value["key"] == "PRI" then
            ASSERT(pk == nil, "一个表里只能拥有一个主键")
            pk = field
        end
    end
    return pk
end

function get_pk_from_index(table_info)
    local pk = nil
    for name, value in pairs(table_info) do
        if name == "PRIMARY" then
            ASSERT(pk == nil, "一个表里只能拥有一个主键")
            pk = value["indexs"]
        end
    end
    return pk
end

function is_key_change(key_config, key_db)
    key_db = key_db == nil and "" or key_db
    key_config = key_config == nil and "" or key_config
    if key_config == key_db then
        return false
    end

    if key_config == "PRI" then
        return false
    end

    if key_config == "NO_UNI" and key_db ~= "" then
        return true
    end

    return true
end

function is_nullable_change(null_config, null_db)
    null_config = tonumber(null_config) == 0 and 0 or 1
    null_db = tonumber(null_db) == 0 and 0 or 1
    return null_config ~= null_db
end

function is_default_change(default_config, default_db)
    default_config = default_config == nil and "" or default_config
    default_db = default_db == nil and "" or default_db
    default_config = trim_reg(default_config, '[\']')
    default_db = trim_reg(default_db, '[\']')
    return default_db ~= default_config
end

function calc_diff_table(tinfo, table_in_db)
    local need_add_cloumn = {}
    local need_modify_cloumn = {}
    local need_del_cloumn = {}
    local table_field_order, table_config = tinfo["field_order"], tinfo["field_map"]
    for _, field in ipairs(table_field_order) do
        local value = table_config[field]
        local db_value = table_in_db[field]
        if not db_value then
            table.insert(need_add_cloumn, value)
        else
            if db_value["type"] ~= value["type"]
             or is_nullable_change(value["nullable"], db_value["nullable"])
             or is_default_change(value["default"], db_value["default"]) then
                table.insert(need_modify_cloumn, value)
            end
        end
    end

    for field, value in pairs(table_in_db) do
        local config_value = table_config[field]
        if not config_value then
            table.insert(need_del_cloumn, value)
        end
    end

    return need_add_cloumn, need_modify_cloumn, need_del_cloumn
end

function check_table_right(tinfo)
    local dbname = tinfo["db"]
    local tablename = tinfo["name"]
    local table_struct = DB_D.get_table(tablename, dbname)
    local table_convert = DB_D.convert_table_info(table_struct)
    local need_add_cloumn, need_modify_cloumn, need_del_cloumn = calc_diff_table(tinfo, table_convert)
    for _,value in ipairs(need_add_cloumn) do
        DB_D.add_cloumn(dbname, tablename, value)
    end

    if DB_D.is_sqlite() and #need_modify_cloumn > 0 then
        LOG.err("error!!!!!! 字段发生变更，sqlite无法变更字段")
    else
        for _,value in ipairs(need_modify_cloumn) do
            local confirm = true
            if value["field"] ~= test_cloumn then
                TRACE("sql_cmd dbname  is %o, modify tablename is %o is %o, 确认执行(Y/N)", dbname, tablename, value)
                local read = BLOCK_READ()
                if read ~= "y" and read ~= "Y" then
                    confirm = false
                end
                TRACE("read is %o, confirm is %o", read, confirm)
            end

            if confirm then
                DB_D.mod_cloumn(dbname, tablename, value)
            end
        end
    end


    if DB_D.is_sqlite() and #need_del_cloumn > 0 then
    else
        for _,value in ipairs(need_del_cloumn) do
            local confirm = true
            if value["field"] ~= test_cloumn then
                TRACE("sql_cmd dbname  is %o, delete  tablename is %o is %o, 确认执行(Y/N)", dbname, tablename, value)
                local read = BLOCK_READ()
                if read ~= "y" and read ~= "Y" then
                    confirm = false
                end
                TRACE("read is %o, confirm is %o", read, confirm)
            end
            if confirm then
                DB_D.del_cloumn(dbname, tablename, value)
            end
        end
    end

end

function calc_diff_index_table(index_config, index_in_db)
    local need_add_index = {}
    local config_pk = get_pk_from_index(index_config)
    local db_pk = get_pk_from_index(index_in_db)

    for name, value in pairs(index_config) do
        local db_value = index_in_db[name]
        if not db_value and name ~= "PRIMARY" then
            need_add_index[name] = value
        end
    end
    return config_pk, db_pk, need_add_index

end

function check_table_index_right(tinfo)
    if DB_D.is_sqlite() then
        return
    end
    local dbname = tinfo["db"]
    local tablename = tinfo["name"]
    local table_struct = DB_D.get_index_table(tablename, dbname)
    local table_convert = DB_D.convert_table_index(table_struct)
    local config_pk, db_pk, need_add_index = calc_diff_index_table(tinfo["index_map"], table_convert)
    if config_pk ~= db_pk then
        DB_D.del_primary_key(dbname, tablename, db_pk)
    end

    for filed,value in pairs(need_add_index) do
        DB_D.add_index(dbname, tablename, value)
    end

    if config_pk ~= db_pk then
        DB_D.add_primary_key(dbname, tablename, config_pk)
    end 
end

function create( )
    load_database("config/dba_database.json")
    ensure_database()
end


create()