-- rid.lua
-- Created by wugd
-- 维护运行中ID

-- 全局变量声明

-- 私有变量声明
local rid_objects = {};

-- 根据RID取对象
function find_object_by_rid(rid)
    return rid_objects[rid];
end

-- 取映射表
function query_rid_objects()
    return rid_objects;
end

-- 取消RID和对象的映射关系
-- 只有拥有RID对象本身允许进行这个调用
function remove_rid_object(rid, caller)
    assert(rid_objects[rid] == caller, "");
    rid_objects[rid] = nil;
end

-- 增加RID和对象的映射关系
function set_rid_object(rid, ob)
    assert(rid_objects[rid] == nil, "");
    rid_objects[rid] = ob;
end

-- 生成新的RID
function NEW_RID(flag)
    flag = flag or "1";
    return (get_next_rid(tonumber(SERVER_ID), flag));
end

-- 快捷访问宏：仅供控制台调试时使用
function RID(rid)
    return (find_object_by_rid(rid));
end
