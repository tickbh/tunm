-- dbase.lua
-- Created by wugd
-- 保存数据的基类

-- 创建类模板
DBASE_TDCLS = tdcls();
DBASE_TDCLS.name = "DBASE_TDCLS";

-- 构造函数
function DBASE_TDCLS:create()
    self.dbase = {};
    self.temp_dbase = {};
    self.change_list = {};
end

-- 定义公共接口，按照字母顺序排序

-- 吸收传入的 dbase 数据
function DBASE_TDCLS:absorb_dbase(data)

    self.change_list["all_change"] = true;

    for key, value in pairs(data) do
        self.dbase[key] = value;
    end
end

function DBASE_TDCLS:absorb_change_list(list)

    for key, _ in pairs(list) do
        self.change_list[key] = true;
    end
end

-- 吸收传入的 temp dbase 数据
function DBASE_TDCLS:absorb_temp_dbase(data)
    for key, value in pairs(data) do
        self.temp_dbase[key] = value;
    end
end

-- Add value to value in dbase
function DBASE_TDCLS:add(key, val)
    local v = self.dbase[key];
    self.change_list[key] = true;

    if not v then
        self:set(key, val);
    elseif is_int(val)  and is_int(v) then
        self.dbase[key] = v + val;
    elseif is_mapping(v) and is_mapping(val) then
        -- mapping 处理
        for key, value in pairs(val) do
            v[key] = value;
        end
    elseif is_array(v) then
        -- array 处理
        table.insert(v, val);
    else
        self.dbase[key] = val;
    end
end

-- Add value to value in temp_dbase
function DBASE_TDCLS:add_temp(key, val)
    local v = self.temp_dbase[key];

    if not v then
        self:set_temp(key, val);
    elseif is_int(val)  and is_int(v) then
        self.temp_dbase[key] = v + val;
    elseif is_mapping(v) and is_mapping(val) then
        -- mapping 处理
        for key, value in pairs(val) do
            v[key] = value;
        end
    elseif is_array(v) then
        -- array 处理
        table.insert(v, val);
    else
        self.temp_dbase[key] = val;
    end
end

-- Add value to value in dbase
-- path 可为 "x/y" 格式
function DBASE_TDCLS:add_ex(path, val)
    local t = express_add(path, self.dbase, val);
    if not t then
        -- 不存在指定路径
        self:set_ex(path, val);
    end
end

-- Add value to value in temp_dbase
-- path 可为 "x/y" 格式
function DBASE_TDCLS:add_temp_ex(path, val)
    local t = express_add(path, self.temp_dbase, val);
    if not t then
        -- 不存在指定路径
        self:set_temp_ex(path, val);
    end
end

function DBASE_TDCLS:delete(key)
    if self.dbase[key] then
        self.change_list[key] = true;
    end

    self.dbase[key] = nil;
end

function DBASE_TDCLS:delete_ex(path)
    if express_query(path, self.dbase) then
        local keys = explode(path, "/");
        self.change_list[keys[1]] = true;

    end
    express_delete(path, self.dbase);
end

function DBASE_TDCLS:delete_temp(key)
    self.temp_dbase[key] = nil;
end

function DBASE_TDCLS:delete_temp_ex(path)
    express_delete(path, self.temp_dbase);
end

-- 冻结 dbase 数据
function DBASE_TDCLS:freeze_dbase()
    self.change_list = {};
end

--获取改变的列表
function DBASE_TDCLS:get_change_list()
    return self.change_list;
end

-- 解冻 dbase 数据
function DBASE_TDCLS:unfreeze_dbase()
    self.change_list["all_change"] = true;
end

-- 判断 dbase 是否冻结中
function DBASE_TDCLS:is_dbase_freezed()

    if sizeof(self.change_list) == 0 then
        return true;
    end
end

function DBASE_TDCLS:set_change_value(key, value)
    self.change_list[key] = value
end

function DBASE_TDCLS:query(key, raw)
    local value;

    if type(key) == "nil" then
        return self.dbase;
    else
        value = self.dbase[key];
        if value then
            return value;
        elseif not raw then
            -- 当没指定只查询自身 dbase 时，需进一步查找本初对象
            local entity = self:basic_object()
            if (self == entity) then
                -- 自身为本初对象，不递归查找，否则会死循环
                return;
            end

            if entity then
                value = entity:query(key, true);
                if value then
                    return (dup(value));
                end
            end
        end
    end

    return nil;
end

function DBASE_TDCLS:querys(keys, raw)
    local result = {}
    for _,v in ipairs(keys) do
        result[v] = self:query(v, raw)
    end
    return result;
end

function DBASE_TDCLS:query_ex(path, raw)
    local value;

    if type(path) == "nil" then
        return self.dbase;
    else
        value = express_query(path, self.dbase);
        if value then
            return value;
        elseif not raw then
            local entity = self:basic_object()
            if (self == entity) then
                -- 自身为本初对象，不递归查找，否则会死循环
                return;
            end

            if entity then
                value = entity:query_ex(path, true);
                if value then
                    return (dup(value));
                end
            end
        end
    end

    return nil;
end

function DBASE_TDCLS:query_sub_temp(key, sub_value)
    if type(key) == "nil" then
        return
    end
    local value = self.temp_dbase[key]
    if is_int(value) then
        value = value - (sub_value or 1);
        self.temp_dbase[key] = value
    end
    return value
end

function DBASE_TDCLS:query_temp(key)
    if type(key) == "nil" then
        return self.temp_dbase;
    else
        return self.temp_dbase[key];
    end
end

function DBASE_TDCLS:query_temp_ex(path)
    if type(path) == "nil" then
        return self.temp_dbase;
    else
        return (express_query(path, self.temp_dbase));
    end
end

function DBASE_TDCLS:replace_dbase(value)
    assert(type(value) == "table", "dbase must be table!");
    self.change_list["all_change"] = true;
    self.dbase = value;
end

function DBASE_TDCLS:replace_temp_dbase(value)
    assert(type(value) == "table", "temp_dbase must be table!");
    self.temp_dbase = value;
end

function DBASE_TDCLS:set(key, value)
    if self.dbase[key] ~= value or type(self.dbase[key]) == "table"
        or type(self.dbase[key]) == "cdata" then
        self.change_list[key] = true;
    end
    if value == "nil" then
        self.dbase[key] = nil;
    else
        self.dbase[key] = value;
    end
    
end

function DBASE_TDCLS:set_ex(path, value)
    local path_value = express_query(path, self.dbase);

    if path_value ~= value or type(path_value) == "table"
        or type(path_value) == "cdata" then
        local keys = explode(path, "/");
        self.change_list[keys[1]] = true;
    end

    express_set(path, self.dbase, value);
end

function DBASE_TDCLS:set_temp(key, value)
    self.temp_dbase[key] = value;
end

function DBASE_TDCLS:set_temp_ex(path, value)
    express_set(path, self.temp_dbase, value);
end
