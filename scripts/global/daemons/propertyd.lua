-- propertyd.lua
-- Created by wugd
-- 负责物件模块

-- 声明模块名
PROPERTY_D = {}
setmetatable(PROPERTY_D, {__index = _G})
local _ENV = PROPERTY_D

local item_file = "data/txt/ItemInfo.txt"
local equip_file = "data/txt/EquipInfo.txt"
local item_table    = {}
local equip_table   = {}
local item_fields_list = {}
local equip_fields_list = {}

-- 相关模块注册回调
local property_callback = {}

-- 定义内部接口，按照字母顺序排序
local function load_item_table()
    item_table = IMPORT_D.readcsv_to_mapping(item_file) or {}

    local item_basic_ob
    local name
    for class_id, info in pairs(item_table) do

        assert(class_id ~= 0,"item表中有class_id为0的道具")
        info = dup(info)
        -- 创建道具基本对象
        if not info["ob_type"] then
            info["ob_type"] = OB_TYPE_ITEM
        end
        item_basic_ob = clone_object(ITEM_TDCLS, info)

        set_class_basic_object(class_id, item_basic_ob)
        name = info["name"]

        if name then
            set_name_basic_object(name, item_basic_ob)
        end

        -- 执行注册的回调函数
        for _, f in ipairs(property_callback) do
            f(info)
        end
        item_table[class_id] = set_table_read_only(info)
    end
end

local function load_equip_table()
    equip_table = IMPORT_D.readcsv_to_mapping(equip_file) or {}

    local equip_basic_ob
    local name
    for class_id, info in pairs(equip_table) do

        assert(class_id ~= 0,"equip表中有class_id为0的道具")
        info = dup(info)
        -- 创建装备基本对象
        if not info["ob_type"] then
            info["ob_type"] = OB_TYPE_EQUIP
        end
        equip_basic_ob = clone_object(EQUIP_TDCLS, info)
        equip_basic_ob:set("amount", 1)

        set_class_basic_object(class_id, equip_basic_ob)
        name = info["name"]

        if name then
            set_name_basic_object(name, equip_basic_ob)
        end

        -- 执行注册的回调函数
        for _, f in ipairs(property_callback) do
            f(info)
        end
        equip_table[class_id] = set_table_read_only(info)
    end
end


-- 定义公共接口，按照字母顺序排序

-- 克隆物件对象
function clone_object_from(class_id, property_info, from_db)
    local basic_object = find_basic_object_by_class_id(class_id)
    if not basic_object then
        -- 没有找到相应的基本对象，不能构造物件
        return
    end

    -- 保存原来信息
    local ori_property_info = dup(property_info)

    if not property_info["rid"] then
        -- 新道具，生成RID
        property_info["rid"] = NEW_RID()
    end

    -- 设置class_id
    property_info["class_id"] = class_id

    -- 设置默认数量
    if not property_info["amount"] then
        property_info["amount"] = 1
    end

    -- 根据不同类型的物件创建对象
    local ob_type = property_info["ob_type"]
    ob_type = ob_type or basic_object:query("ob_type")

    local property_ob
    if ob_type == OB_TYPE_ITEM then
        -- 创建道具对象
        property_ob = clone_object(ITEM_TDCLS, property_info)
    elseif ob_type == OB_TYPE_EQUIP then
        property_ob = clone_object(EQUIP_TDCLS, property_info)
        ori_property_info["amount"] = nil
        if not property_ob:query("lv") then
            property_ob:set("lv", 0)
        end
        if not property_ob:query("exp") then
            property_ob:set("exp", 0)
        end
    end

    if from_db ~= true then
        -- 物件不再数据库中，执行物件初始化脚本
        -- local init_script = property_ob:query("init_script")
        -- if (is_int(init_script) and init_script > 0) then
        --     INVOKE_SCRIPT(init_script, property_ob, property_ob:query("init_arg"), instance_id)
        -- end

        -- 表示该物件不在数据库中，记录标识，以便该物件加载到玩家身上后，
        -- 保存玩家数据时，使用 insert 操作而非 update 操作
        property_ob:set_temp("not_in_db", true)
    end

    -- 防止传入数据被初始化脚本覆盖
    property_ob:absorb_dbase(ori_property_info)

    return property_ob
end

function get_property_info(class_id)
    if equip_table[class_id] then
        return equip_table[class_id]
    elseif item_table[class_id] then
        return item_table[class_id]
    end
end

-- 取得指定 class_id 的物件信息
function get_item_info(class_id)
    if not class_id then
        return item_table
    else
        return item_table[class_id]
    end
end

function get_equip_table(class_id)
    if not class_id then
        return equip_table
    else
        return equip_table[class_id]
    end
end

function get_item_or_equip_info(class_id)
    assert(class_id and class_id > 0," class_id must > 0")
    if item_table[class_id] then
        return item_table[class_id]
    else
        return equip_table[class_id]
    end
end

-- 注册其他模块需要收集的道具信息
function register_property_callback(f)
    property_callback[#property_callback + 1] = f
end

local function init()
    -- 加载道具表
    load_item_table()
    load_equip_table()
end
 
-- 模块的入口执行
function create()
    register_post_init(init)
end

create()
