-- attribd.lua
-- 负责属性相关的功能模块

-- 声明模块名
module("ATTRIB_D", package.seeall);

attrib_formula = {};
attrib_max_list     = {};

---- 定义公共接口，按照字母顺序排序

function get_max_attrib(ob_type, key)
    local attrib_max = attrib_max_list[ob_type] or {};
    return attrib_max[key]
end

-- 查询对象属性值
function query_attrib(ob, attrib)
    local ob_type = ob:query("ob_type");
    local attrib_info = attrib_formula[ob_type];
    if not attrib_info then
        -- 该属性没有配置相应的公式
        return (ob:query(attrib));
    end

    local formula = attrib_info[attrib];
    if not formula then
        -- 该对象的该属性没有配置相应的公式
        return (ob:query(attrib));
    end

    -- 调用公式取得该属性值
    return (formula(ob, attrib));
end

--执行属性增加操作
function add_attrib(ob, field, value)
    trace("add_attrib ob is %o" , {ob, field, value})
    if not is_object(ob) or value == 0  then
        return false;
    end

    --增加金钱,将ob变成玩家ob
    if field == "money" then
        if not ob or ob:query("ob_type") ~= OB_TYPE_USER then
            return false;
        end
    end

    local value = math.floor(value);
    local cur_value = ob:query(field);

    --不存在字段field，则初始化为0
    if not cur_value then
        cur_value = 0;
    end

    local final_value = value + math.floor(cur_value);
    local attrib_max = attrib_max_list[ob:query("ob_type")] or {};

    --查看是否达到满级
    if field == "exp" and not ob:is_equip() and not attrib_max["lv"] then
        if attrib_max["lv"] <= ob:query("lv") then
            return false;
        end
    end

    if field == "sp" and ob:is_user() and not ob:query_temp("sp_is_buy") then
        local max_sp = CALC_SP_MAX(ob)
        trace("max_sp = %o, cur_value = %o, final_value = %o\n", max_sp, cur_value, final_value)
        if cur_value > max_sp then
            final_value = cur_value
        elseif final_value > max_sp then
            final_value = max_sp
        end
    end

    -- if statistics_add_log_id[field] then
    --     local owner_ob = get_owner(ob)
    --     if owner_ob then
    --         LOG_D.to_log(statistics_add_log_id[field], get_ob_rid(owner_ob), tostring(value), tostring(final_value), "", owner_ob:query_log_channel())
    --     end
    -- end

    --超过上限,则取上限值
    if attrib_max[field] and final_value > attrib_max[field] then
        final_value = attrib_max[field];

        -- if field == "money" then
        --     ob:notify_dialog_ok($$[86]);
        -- elseif field ~= "vp" then
        --     ob:notify_dialog_ok(string.format($$[6], field));
        -- end
    end

    ob:set(field, final_value);
    trace("attrib filed is %o, final_value is %o", field, final_value)
    ob:notify_fields_updated(field);

    if field == "money" then
        -- 发起获取金币的事件
        raise_issue("ATTRIB_D", SF_CHANGE_MONEY, ob, value);
    end

    return true;
end

--执行属性消耗操作
function cost_attrib(ob, field, value)
    if not is_object(ob) then
        return false;
    end

    local value = math.ceil(value);
    local cur_value = ob:query(field);

    --不存在字段field，或者结果小于零, 扣除失败
    if not cur_value  or  cur_value - value < 0  or value == 0 then
        return false;
    end

    local final_value = cur_value - value;

    ob:set(field, final_value);
    ob:notify_fields_updated(field);

    if field == "gold" then
        -- 发起消耗金币的事件
        raise_issue(EVENT_GOLD_COST, ob, -1*value);
    elseif field == "stone" then
        -- 发起消耗钻石事件
        raise_issue(EVENT_STONE_COST, ob, -1*value);        
    elseif field == "sp" then
        -- 发起消耗钻石事件
        raise_issue(EVENT_PHY_COST, ob, -1*value);
    end

    -- if statistics_cost_log_id[field] then
    --     local owner_ob = get_owner(ob)
    --     if owner_ob then
    --         LOG_D.to_log(statistics_cost_log_id[field], get_ob_rid(owner_ob), tostring(value), tostring(final_value), "", owner_ob:query_log_channel())
    --     end
    -- end

    return true;
end


-- 模块的入口执行
function create()
    local data = IMPORT_D.readcsv_to_tables("data/txt/attrib_formula.txt");

    local attrib, ob_type;
    for _, info in ipairs(data) do
        attrib  = info["attrib"];
        info["ob_type"] = _G[info["ob_type"]]
        ob_type = info["ob_type"];

        if not is_mapping(attrib_formula[ob_type]) then
            attrib_formula[ob_type] = {};
        end

        attrib_formula[ob_type][attrib] = _G[info["formula"]];
    end

    local max_list = IMPORT_D.readcsv_to_tables("data/txt/attrib_max.txt");
    for _, info in pairs(max_list) do
        info["ob_type"] = _G[info["ob_type"]]
        attrib_max_list[info.ob_type] = attrib_max_list[info.ob_type] or {};
        attrib_max_list[info.ob_type][info.name] = info.max;
    end

end

create();
