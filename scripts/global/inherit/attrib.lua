-- attrib.lua
-- Created by wugd
-- 属性基类

-- 创建类模板
ATTRIB_TDCLS = tdcls();
ATTRIB_TDCLS.name = "ATTRIB_TDCLS";

-- 构造函数
function ATTRIB_TDCLS:create(para)
end

-- 定义公共接口，按照字母顺序排序

-- 查询对象属性值
function ATTRIB_TDCLS:query_attrib(key, raw)
    return (ATTRIB_D.query_attrib(self, key));
end

-- 增加属性操作
function ATTRIB_TDCLS:add_attrib(field, value)
   return (ATTRIB_D.add_attrib(self, field, value));
end

-- 消耗属性操作
function ATTRIB_TDCLS:cost_attrib(field, value)
    return (ATTRIB_D.cost_attrib(self, field, value));
end

-- 查询属性是性足够
function ATTRIB_TDCLS:has_attrib(info)
    for k,v in pairs(info) do
        if self:query_attrib(k) < v then
            return false, k
        end
    end
    return true
end

-- 扣除批量属性
function ATTRIB_TDCLS:cost_attribs(info)
    for k,v in pairs(info) do
        self:cost_attrib(k, v)
    end
end