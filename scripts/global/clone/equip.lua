-- equip.lua
-- Created by xyf, 2012.9.10
-- 装备对象类

-- 创建类模板
EQUIP_CLASS = class(DBASE_CLASS, RID_CLASS, PROPERTY_CLASS, ATTRIB_CLASS);
EQUIP_CLASS.name = "EQUIP_CLASS";

-- 构造函数
function EQUIP_CLASS:create(value)
    assert(type(value) == "table", "equip::create para not corret");
    assert(is_int(value["class_id"]));

    --装备和装扮默认为1,在基本对象中设置
    value["amount"] = nil;
    self:replace_dbase(value);
end

-- 析构函数
function EQUIP_CLASS:destruct()
end

-- 生成对象的唯一ID
function EQUIP_CLASS:get_ob_id()
    return (string.format("EQUIP_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("class_id"))));
end

-- 定义公共接口，按照字母顺序排序

--获取基本类的对象
function EQUIP_CLASS:basic_object()
    local class_id = self.dbase["class_id"]
    return (find_basic_object_by_class_id(class_id))
end

-- 道具是否可叠加
function EQUIP_CLASS:can_combine(ob)
   return false;
end

-- 道具扣除数量,返回实际扣除个数
function EQUIP_CLASS:cost_amount()
    -- 析构道具
    local owner = self:get_container();
    if owner then
        owner:drop(self);
        return true;
    end
end

-- 取得数据库的保存操作
function EQUIP_CLASS:get_save_oper()
    local oper = self:query_temp("not_in_db") and "insert" or "update";

    return "equip", self:query("rid"), oper;
end

function EQUIP_CLASS:is_equip()
    return true;
end

-- 通知字段变更
function EQUIP_CLASS:notify_fields_updated(field_names)
    local env = self:get_container();
    if not env then
        return;
    end

    env:notify_property_updated(self:get_rid(), field_names);
end

-- 取得保存数据库的信息
function EQUIP_CLASS:save_to_mapping()

    --insert操作,返回全部数据
    if self:query_temp("not_in_db") then
        return (self:query());
    end

    -- 道具数据发生变化的字段
    local change_list = self:get_change_list();
    local data = {};

    for key,_ in pairs(change_list) do
        if PROPERTY_D.is_in_equip_fields(key) then
            data[key] = self:query(key);
        else
            return (self:query());
        end
    end

    if sizeof(data) == 0 then
        return;
    end

    return data, 1;
end

-- 还原dbase数据
function EQUIP_CLASS:restore_from_mapping(data, freeze)
    self:absorb_dbase(data);

    -- 设置 dbase 冻结中，若没被解冻，下线不额外进行保存
    if freeze then
        self:freeze_dbase();
    end
end
