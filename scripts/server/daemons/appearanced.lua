-- appearanced.lua
-- Created by wugd
-- 负责各实体的外观获取

--声明模块
APPEARANCE_D = {}
setmetatable(APPEARANCE_D, {__index = _G})
local _ENV = APPEARANCE_D

--创建模块变量，保存描述信息
local appearance_table = {}

---- 定义公共接口，按照字母顺序排序

-- 构建对象信息
function build_object_info(ob, fields_list, extra_data)
    local query_attrib_func = ATTRIB_D.query_attrib
    local query_func        = ob.query
    local query_temp_func   = ob.query_temp
    local is_table = is_table
    local buffer_to_string = buffer_to_string

    if not fields_list then
        fields_list = get_appearance_fields_by_ob_type(query_func(ob, "ob_type"), "SELF")
    end

     --获取各个字段的值
     local value
     local ob_info = {}
     local is_equip = ob:is_equip()
     for _, field in pairs(fields_list) do

        if field == "props" then
            if query_func(ob, "props") then
                for i, name in pairs (query_func(ob, "props")) do
                    ob_info[name] = query_attrib_func(ob, name)
                end
            end
        else

            value = query_attrib_func(ob, field)
            if not value then
                value = query_func(ob, field)
            end

            if not value then
                value = query_temp_func(ob, field)
                if not value and is_table(extra_data) then
                    value = extra_data[field]
                end
            end

            ob_info[field] = value
        end
    end

    return ob_info
end

-- 获取要传送到客户端的外观描述信息
function get_appearance(entity_or_rid, group)

    --如果传入的为rid号，则获取实体对象
    local entity
    if is_string(entity_or_rid) then
        entity = find_object_by_rid(entity_or_rid)
    else
        entity = entity_or_rid
    end

    local appearance = {}

    --获取外观信息的字段名
    local appearance_fields = get_appearance_fields_by_ob_type(entity:query("ob_type"), group)

    --获取各个字段的值
    local properties = {}
    local page, x, y
    local read_pos = READ_POS
    local is_in_array = is_in_array
    local type = type
    for i, field in ipairs(appearance_fields) do

        --如果字段名为数组，则表示页面列表
        if type(field) == "table" then

            -- 取得指定页下的所有物件的外观信息
            for pos, ob in pairs(entity.carry) do
                x, y = read_pos(pos)

                if is_in_array(x, field) then
                    -- 取得该物件的外观
                    properties[#properties + 1] = get_appearance(ob, group)
                end
            end

            appearance_fields[i] = nil
        end
    end

    clean_array(appearance_fields)

    -- 构建对象外观信息
    appearance = build_object_info(entity, appearance_fields)

    if sizeof(properties) ~= 0 then
        -- 记录在 properties 字段下
        appearance["properties"] = properties
    end

    return appearance
end

--获取要传送到客户端的外观描述信息字段
function get_appearance_fields_by_ob_type(ob_type, group)

    if not group then
        group = "SELF"
    end

    local apprance_fields = appearance_table[ob_type][group] or {}
    return (dup(apprance_fields))
end

function get_appearance_table()
    return appearance_table
end

--加载配置表，获取各实体需要发送的外观描述字段
--[[
appearance_table = {
                     OB_USER_TYPE = {
                                        SIMPLE = { rid,
                                                   hair,
                                                   body,
                                                   ...
                                                 }
                                        DETAIL = {
                                                    ...
                                                 }
                                        ...
                                    }
                        ...
                   }

--]]
local function load_appearance_csv(filename)

    local temp_table = IMPORT_D.readcsv_to_tables(filename)
    local group_table = {}
    local appearance_temp = {}

    for _, v in pairs(temp_table) do
        v["type"] = _G[v["type"]] or 0
        appearance_temp[v["type"]] =  appearance_temp[v["type"]] or {}

        group_table[v["type"]] = group_table[v["type"]] or {}
        local now, last = 1,1
        while true do
            now = string.find(v["group"], "|", last)

            local group

            if now then
                 group = string.sub(v["group"], last, now-1)
                 last = now + 1
            else
                 group = string.sub(v["group"], last, -1)
            end

            group_table[v["type"]][group] = true

            --防止在数组中存放的字段重复，先用mapping存储
            appearance_temp[v["type"]][group] =  appearance_temp[v["type"]][group] or {}
            appearance_temp[v["type"]][group][v["attrib"]] = true

            if not now then
                break
            end
        end
    end

    --将*组的所有数据移动到其他组

    for ob_type, ob_table in pairs(appearance_temp) do

        group_table[ob_type]["*"] = nil

        if ob_table["*"] then
            for field, _ in pairs(ob_table["*"]) do

                for group,_ in pairs(group_table[ob_type]) do
                    ob_table[group][field] = true
                end
            end
        end

        ob_table["*"] = nil
    end

    --将appearance_table变成数组
    for ob_type, ob_table in pairs(appearance_temp) do
        appearance_table[ob_type] = {}

        for group, field_table in pairs(ob_table) do
            appearance_table[ob_type][group] = {}

            local page
            local page_list = {}
            for field, _ in pairs(field_table) do
                page = string.match(field, "(%d*)%-%*")
                if page then
                    page_list[#page_list + 1] = to_int(page)
                else
                    appearance_table[ob_type][group][#appearance_table[ob_type][group] + 1] = field
                end
            end

            if sizeof(page_list) > 0 then
                appearance_table[ob_type][group][#appearance_table[ob_type][group] + 1] = page_list
            end
        end
    end
end

-- 模块的入口执行
function create()
    load_appearance_csv("data/txt/appearance.txt")
end

create()
