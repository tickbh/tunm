-- property.lua
-- Created by wugd
-- 物件基类

-- 创建类模板
PROPERTY_TDCLS = tdcls();
PROPERTY_TDCLS.name = "PROPERTY_TDCLS";

-- 构造函数
function PROPERTY_TDCLS:create(para)
end

-- 析构函数
function PROPERTY_TDCLS:destruct()

end

-- 定义公共接口，按照字母顺序排序
-- 取得该物件所在的容器对象
function PROPERTY_TDCLS:get_container()
    assert(self:query("owner") == self:query_temp("container"));

    local owner_rid = self:query("owner");
    if owner_rid then
        return (find_object_by_rid(owner_rid));
    end
end

-- 取得该物件所在的属主对象
function PROPERTY_TDCLS:get_owner()
    assert(self:query("owner") == self:query_temp("container"));

    local owner_rid = self:query("owner");
    if owner_rid then
        return (find_object_by_rid(owner_rid));
    end
end
