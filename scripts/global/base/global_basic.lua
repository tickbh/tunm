-- global_basic.lua
-- Created by wugd
-- 维护基本对象

--变量定义
local class_basic_ob = {}
local name_basic_ob = {}

-- 定义公共接口，按照字母顺序排序

--根据class_id查找对象
function find_basic_object_by_class_id(class_id)
    return class_basic_ob[class_id]
end

--根据name查找对象
function find_basic_object_by_name(name)
    return name_basic_ob[name]
end

--根据class_id设置对象
function set_class_basic_object(class_id,basic_ob)
    class_basic_ob[class_id] = basic_ob
end

--根据name设置对象
function set_name_basic_object(name,basic_ob)
    name_basic_ob[name] = basic_ob
end



