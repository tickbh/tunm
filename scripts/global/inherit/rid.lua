-- rid.lua
-- Created by wugd
-- RID基类

-- 创建类模板
RID_TDCLS = tdcls();
RID_TDCLS.name = "RID_TDCLS";

-- 构造函数
function RID_TDCLS:create(para)
    if not para then
        return;
    end
    local rid = para["rid"];
    if rid then
        self:set_rid(rid);
    end
end

-- 析构函数
function RID_TDCLS:destruct()
    local rid = self:query("rid");
    if rid then
        remove_rid_object(rid, self);
    end
end

-- 定义公共接口，按照字母顺序排序

-- 取得 rid
function RID_TDCLS:get_rid()
    return (self:query("rid"));
end

-- 设置对象的RID，每个对象的RID只能被设置一次
function RID_TDCLS:set_rid(rid)
    assert(not self:query("rid"), "");

    self:set("rid", rid);
    set_rid_object(rid, self);
end
