-- containerd.lua
-- Created by wugd
-- 容器相关功能

-- 声明模块名
CONTAINER_D = {}
setmetatable(CONTAINER_D, {__index = _G})
local _ENV = CONTAINER_D

-- 定义公共接口，按照字母顺序排序

-- 取得物件对应的格子页面
function get_page(ob)
    local ob_type
    if is_object(ob) then
        ob_type = ob:query("ob_type")
        if ob_type == OB_TYPE_ITEM  or ob_type == OB_TYPE_EQUIP then
            -- 若为道具，则 ob_type 即为页面号
            return (ob:query("ob_type"))
        end
    end
end

function get_page_by_data(info)
    local ob_type = info["ob_type"]
    if ob_type == OB_TYPE_ITEM  or ob_type == OB_TYPE_EQUIP then
        -- 若为道具，则 ob_type 即为页面号
        return info["ob_type"]
    end
end


-- 模块的入口执行
function create()
end

create()
