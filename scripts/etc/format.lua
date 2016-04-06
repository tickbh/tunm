--format目录，实际项目可移至策划目录，让策划进行维护

function GET_GOLD_ID()
    return 101
end

function GET_STONE_ID()
    return 102
end

function CALC_ITEM_MAX_AMOUNT(ob)
    if is_object(ob) then
        return ob:query("over_lap") or 1
    elseif is_table(ob) then
        return ob["over_lap"] or 1
    else
        return 1
    end
end