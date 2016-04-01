--游戏相关的方法

function get_ob_rid(ob)
    assert(is_object(ob), "must be a object")
    return ob:query("rid")
end

-- 生成 pos
function MAKE_POS(x, y)
    return (string.format("%d-%d", x, y));
end

-- 读取 pos
function READ_POS(pos)
    local x, y = string.match(pos, "(%d+)-(%d+)");
    return tonumber(x), tonumber(y);
end

function is_rid_vaild(rid)
   return string.len(rid or "") == 12
end

function check_rid_vaild(rid)
   assert(is_rid_vaild(rid), "rid 必须为12位")
end

function set_not_in_db(ob)
    assert(is_object(ob), "must be an object")
    ob:set_temp("not_in_db", true)
end

function del_not_in_db(ob)
    assert(is_object(ob), "must be an object")
    ob:delete_temp("not_in_db")
end

function is_not_in_db(ob)
    assert(is_object(ob), "must be an object")
    return ob:query_temp("not_in_db") == true
end

function get_owner(ob)
    if is_object(ob) then
        --如果没有属主，就返回自己
        return find_object_by_rid(ob:query("owner") or ob:get_rid())
    elseif is_table(ob) then
        return find_object_by_rid(ob["owner"] or "")
    end
    return nil
end

function get_owner_rid(ob)
    if is_object(ob) then
        --如果没有属主，就返回自己
        return ob:query("owner")
    elseif is_table(ob) then
        return ob["owner"]
    end
    return nil
end

function is_auto_rid(rid)
    if string.len(rid) == 17 and string.find(rid, "auto_") then
        return true
    end
    return false
end