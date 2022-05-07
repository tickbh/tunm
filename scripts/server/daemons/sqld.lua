-- sqld.lua
-- 声明模块名

_LT  = "_LT" -- <
_LTE = "_LTE" -- <=
_GT  = "_GT" -- >
_GTE = "_GTE" -- >=
_NE  = "_NE" -- <>
_LIKE = "_LIKE" -- like

_LIMIT = "_LIMIT" 
_OFFSET = "_OFFSET"
_ORDER = "_ORDER"

_AND = "_AND"
_OR = "_OR"

_DESC = "_DESC"
_ASC = "_ASC"

_FIELDS = "_FIELDS"
_WHERE = "_WHERE"
_ACT = "_ACT"

SQL_D = {}
setmetatable(SQL_D, {__index = _G})
local _ENV = SQL_D

local sql_table = {
    _LT = "<",
    _LTE = "<=",
    _GT  = ">", -- >
    _GTE = ">=", -- >=
    _NE  = "<>", -- <>
    _LIKE = "like", -- like
    _LIMIT = "limit", 
    _OFFSET = "offset",
    _AND = "and",
    _OR = "or",
}

function convert_db_key( value )
    if IS_STRING(value) then
        return string.format("`%s`", value)
    elseif IS_INT(value) then
        return tostring(value)
    else
        return value
    end
end

function convert_to_sql(value)
    if IS_STRING(value) then
        return "'" .. value .. "'"
    elseif IS_INT(value) then
        return tostring(value)
    else
        return value
    end
end

function piece_one_condition( key, condition)
    if not condition then
        return ""
    end
    local result = ""
    local convert_key = convert_db_key(key)
    local convert_val
    if not IS_TABLE(condition) then
        result = convert_key .. "=" .. convert_to_sql(condition)
    else
        local defaultLink = condition[_ACT] or _AND
        for k,val in pairs(condition) do
            convert_val = convert_to_sql(val)
            if SIZEOF(result) > 0 then
                result = result .. " " .. sql_table[defaultLink] .. " "
            end
            if k == _LT or k == _LTE or k == _GT or k == _GTE or k == _NE or k == _LIKE then
                result = result .. " " .. convert_key .. " " .. sql_table[k] .. " " ..  convert_val
            end
        end
    end
    return result
end

function piece_single_where( condition )
    if not condition then
        return ""
    end
    local result
    for k,v in pairs(condition) do
        result = piece_one_condition(k, v)
        break
    end
    return result
end

function piece_where_condition( table_name, condition )
    if not condition then
        return ""
    end
    local defaultLinkValue = sql_table[condition[_ACT] or _AND]
    local where_condition = condition[_WHERE]
    local result = ""
    if IS_ARRAY(where_condition) then
        for _,val in ipairs(where_condition) do
            if SIZEOF(result) > 0 then
                result = result .. " " .. defaultLinkValue .. " "
            end
            result = result .. piece_single_where(val)
        end
    elseif IS_TABLE(where_condition) then 
        result = piece_single_where(where_condition)
    end
    if SIZEOF(result) > 0 then
        return " where " .. result .. " " 
    end
    return ""
end

function piece_select_fields(table_name, condition)
    if not condition then
        return "*"
    end
    local fields = condition[_FIELDS]
    if not fields then
        return "*"
    else
        local result = ""
        for _,v in ipairs(fields) do
            if SIZEOF(result) > 0 then
                result = result .. ","
            end
            result = result .. string.format("`%s`", v)
        end
        return result
    end
end

function piece_select_offset( table_name, condition )
    if not condition then
        return ""
    end
    local offset = condition[_OFFSET]
    if not offset then
        return ""
    end
    return " offset " .. tostring(offset) .. " "
end

function piece_select_order( table_name, condition )
    if not condition then
        return ""
    end
    local order = condition[_ORDER]
    if not order or not IS_TABLE(order) then
        return ""
    end
    local key, value = nil, nil
    for k,v in pairs(order) do
        key, value = k, v
        break
    end
    if not key then
        return ""
    end
    return " ORDER BY `" .. key .. "` " .. value .. " "
end

function piece_select_limit( table_name, condition )
    if not condition then
        return ""
    end
    local limit = condition[_LIMIT]
    if not limit then
        return ""
    end
    return " limit " .. tostring(limit) .. " "
end

function select_sql( table_name, condition )
    local result = "SELECT " .. piece_select_fields(table_name, condition) .. " FROM " .. table_name
    result = result .. piece_where_condition(table_name, condition)
    result = result .. piece_select_order(table_name, condition)
    result = result .. piece_select_limit(table_name, condition)
    result = result .. piece_select_offset(table_name, condition)
    return result
end

function encode_table_data(table_name, data)
    local tabledata = DATA_D.get_table_fields(table_name) or {}
    local result = {misc={}}
    for k,v in pairs(data) do
        if not tabledata[k] then
            result.misc[k] = v
        else
            result[k] = v
        end
    end
    if tabledata.misc then
        result.misc = ENCODE_JSON(result.misc)
    else
        result.misc = nil
    end
    --TRACE("encode_table_data table_name is %o, tabledata is %o, result is %o", table_name, tabledata, result)
    return result
end

function decode_table_data(table_name, data) 
    local result = DUP(data)
    result.misc = DECODE_JSON(data.misc)
    for k,v in pairs(result.misc) do
        result[k] = v
    end
    result.misc = nil
    return result
end

function piece_insert_sql( table_name, data )
    data = encode_table_data(table_name, data)
    local field_key = ""
    local field_val = ""
    for k,v in pairs(data) do
        if SIZEOF(field_key) > 0 then
            field_key = field_key .. ","
            field_val = field_val .. ","
        end
        field_key = field_key .. convert_db_key(k)
        field_val = field_val .. convert_to_sql(v)
    end
    return "(" .. field_key .. ")" .. " VALUES (" .. field_val .. ")" 
end

function insert_sql( table_name, data )
    local sql = piece_insert_sql(table_name, data)
    return "INSERT INTO " .. convert_db_key(table_name) .. sql
end

function piece_update_sql(table_name, data)
    local update_data = encode_table_data(table_name, data)
    if not data["misc"] then --混合字段只有主动更新才进行更新
        update_data["misc"] = nil
    end
    local result = ""
    for k,v in pairs(data) do
        if SIZEOF(result) > 0 then
            result = result .. ","
        end
        result = result .. " `" .. k .. "` = " .. convert_to_sql(v)
    end
    return result 

end

function update_sql( table_name, data, condition )
    local sql = piece_update_sql(table_name, data)
    if condition and not condition[_WHERE] then
        local tmp = condition
        condition = {}
        condition[_WHERE] = tmp
    end
    local where_sql = piece_where_condition(table_name, condition)
    return "UPDATE " .. table_name .. " SET " .. sql .. where_sql
end

function delete_sql( table_name, condition )
    if condition and not condition[_WHERE] then
        local tmp = condition
        condition = {}
        condition[_WHERE] = tmp
    end
    local where_sql = piece_where_condition(table_name, condition)
    return "DELETE FROM " .. table_name .. " " .. where_sql
end



-- 'IS_ARRAY({[1]=2,[2]=3,act="and"})

-- 'IS_ARRAY({[1]=2,[2]=3})

-- SQL_D.select_sql("author", {_FIELDS={"me","you","he"}, _WHERE={he=21}, _LIMIT=2, _OFFSET=3})
-- 'SQL_D.select_sql("author", {_FIELDS={"me","you","he"}, _WHERE={he={_LT=2}}, _LIMIT=2, _OFFSET=3})

-- 'SQL_D.insert_sql("author", {fda="fd",er="re"})

-- 'SQL_D.update_sql("author", {fda="fd",er="re"}, {he={_LT=2}})
-- 'SQL_D.update_sql("author", {fda="fd",er="re"})

-- 'SQL_D.delete_sql("author", {he={_LT=2}})

--                 {   "field" : "account",                   "type" : "string",      "len" : 12,             "key" : "primary"   },
--                 {   "field" : "device_id",                 "type" : "string",      "len" : 32                                  },
--                 {   "field" : "rid",                       "type" : "string",      "len" : 12,             "key" : "unique"    },
--                 {   "field" : "name",                      "type" : "string",      "len" : 18                                  },
--                 {   "field" : "password",                  "type" : "string",      "len" : 32                                  },
--                 {   "field" : "takeover_pwd",              "type" : "string",      "len" : 32                                  },
--                 {   "field" : "is_freezed",                "type" : "int",         "len" : 1                                   },
--                 {   "field" : "emoney",                    "type" : "int",         "len" : 32                                  },
--                 {   "field" : "misc",                      "type" : "string",      "len" : 1024                                },

-- 'SQL_D.insert_sql("author", {account="myuser",device_id="2323232", rid="fdkaskjfdk", name="you", test="dfdsa", test2="fdsafds"})

-- DB_D.execute_db("hddb3", SQL_D.insert_sql("account", {account="myuser",device_id="2323232", rid="fdkaskjfdk", name="you", test="dfdsa", test2="fdsafds"}))

-- DB_D.read_db("hddb3", SQL_D.select_sql("account"))

-- DB_D.execute_db("hddb3", SQL_D.update_sql("account", {name="he"}))

-- DB_D.execute_db("mser", SQL_D.delete_sql("user"))

-- 'DB_D.sync_execute_db("hddb3", SQL_D.select_sql("account"))

-- 'DB_D.sync_execute_db("mser", SQL_D.select_sql("account"))


-- x, y = DB_D.sync_execute_db("mser", SQL_D.select_sql("account"))
-- 'x
-- 'y
-- sync_execute_db

-- '