-- bonusd.lua
-- Created by wugd
-- 负责奖励相关的功能模块

-- 声明模块名
module("BONUS_D", package.seeall);

local bonus_times_list={};
local bonus_times_limit_list = {};
local MAX_INTERVAL = 600;

--定义内部函数
--执行奖励属性操作
local function attrib_bonus(attribs, bonus_type)
    trace("attrib_bonus attribs is %o", attribs)
    local attrib_list = {};
    local money = {};

    --分别对attribs里的对象执行奖励操作
    for _, info in pairs(attribs) do
        local attrib = {};
        local ctr_ob;
        local ob = remove_get(info, "ob");
        if ob and ob:get_owner() then
            ctr_ob = ob:get_owner()
        end
        ctr_ob = ctr_ob or ob;
        trace("ob type is %o", ctr_ob:query("ob_type"))
        --不存在属主，或者ob不是玩家，则不操作;
        if ctr_ob and ctr_ob:query("ob_type") == OB_TYPE_USER then

            local ctr_rid = ctr_ob:get_rid();
            local ob_rid  = ob:get_rid();

            --依次增加属性
            for field, value in pairs(info) do
                local ori_value = ob:query(field) or 0;
                local cfg_value = value;

                --如果为金钱,再判断是否有多倍率
                if field == "money" then
                    -- 如果有多倍金钱活动，则乘上倍率
--                  cfg_value = value*ACTIVITY_MULTIPLE_MONEY.get_money_multiple();
                end

                --如果操作成功，记录日志,以及要发送给客户端的信息
                if ATTRIB_D.add_attrib(ob, field, cfg_value) then
                    -- value为实际增加的值
                    value = math.min(ob:query(field) - ori_value, cfg_value);

                    --如果为金钱，先统计，后面再记录
                    if field == "money" then
                        money[ctr_rid] = money[ctr_rid] or 0;
                        money[ctr_rid] = money[ctr_rid] + value;

                    --记录经验值，并写入日志
                    elseif field == "exp"then
                        trace("ob is %o ob+type = %o", ob, ob:query("ob_type"))
                        if ob:query("ob_type") == OB_TYPE_USER then
                            USER_D.try_level_up(ob);
                        elseif ob:query("ob_type") == OB_TYPE_HERO then
                            HERO_D.try_level_up(ob);
                        end

                        attrib["exp"] = value;
                        --LOG_D.to_log(LOG_TYPE_EXP, ob_rid, tostring(value), "", "");
                    else
                        attrib[field] = value;
                    end
                end
            end
              --初始化map;
            attrib_list[ctr_rid] = attrib_list[ctr_rid] or {};
            attrib_list[ctr_rid][ob_rid] = attrib_list[ctr_rid][ob_rid] or {};

            --累加数据
            for field, value in pairs(attrib) do
                attrib_list[ctr_rid][ob_rid][field] = attrib_list[ctr_rid][ob_rid][field] or 0;
                attrib_list[ctr_rid][ob_rid][field] = attrib_list[ctr_rid][ob_rid][field] + value;
            end
        else
            trace("ERROR: container ob is not a user in BONUS_D.attrib_bonus\n");
        end
    end

    local attrib_list_temp ={};

    --整理attrib_list,将ctr_rid对应的值改为数组；
    --将ob_rid,存入对应的值中；
    for ctr_rid, info in pairs(attrib_list) do

        local attrib_array = {};
        for ob_rid, attrib_info in pairs(info) do
            attrib_info["rid"] = ob_rid;
            attrib_array[#attrib_array + 1] = attrib_info;
        end
        attrib_list_temp[ctr_rid] = attrib_array;
    end

    return attrib_list_temp;
end

-- 组合bonus_info中的property信息(只针对道具，考虑到可叠加问题)
function cal_property(property, class_id, amount, ob)
    if not property then
        property = {};
    end

    -- 最大可叠加数
    local max_amount = CALC_ITEM_MAX_AMOUNT(class_id);
    local integer    = math.floor(amount/max_amount);
    local remainder  = amount % max_amount;

    -- 整数部分
    for i=1, integer do
        property[#property+1] =
                {
                    ob       = ob,
                    class_id = class_id,
                    amount   = max_amount,
                }
    end

    -- 有余数的话
    if remainder > 0 then
        property[#property+1] =
                {
                    ob       = ob,
                    class_id = class_id,
                    amount   = remainder,
                }
    end

    return property;
end

--执行奖励道具操作
local function property_bonus(propertys, bonus_type)
    trace("property_bonus is %o", propertys)
    local list ={};
    for _, info in pairs(propertys) do
        -- 取出额外参数
        local extra = remove_get(info, "extra") or {}
        local ob = remove_get(info, "ob");

        --若该对象是玩家，则加载道具
        if ob and ob:query("ob_type") == OB_TYPE_USER then

            local ob_rid = ob:get_rid();
            list[ob_rid] =  list[ob_rid] or {};

            local success, gain_list = ob:get_container():recieve_property(info)
            trace("------------ recieve info %o, success is %o, gain_list is %o", info, success, gain_list)
            if success then
                for _,v in pairs(gain_list) do
                    table.insert(list[ob_rid], v)
                end
            end
        else
            trace("ERROR: ob is not a user_type in BUNOS_D.property_bonus\n");
        end
    end

    return list;
end

local function caculate_bonus_property_times(property_info)
    do return end
    local temp_list ={};

    for _, info in pairs(property_info) do

        if is_object(info["ob"]) and info["ob"]:query("ob_type") == OB_TYPE_USER then
            temp_list[info["ob"]:query("rid")] = true;
        end
    end

    --添加道具奖励的次数
    for rid,_ in pairs(temp_list) do
        bonus_times_list[rid] = bonus_times_list[rid] or {};
        bonus_times_list[rid].property = bonus_times_list[rid].property or 0;
        bonus_times_list[rid].property = bonus_times_list[rid].property + 1;
    end
end

local function caculate_bonus_attrib_times(attrib_info)
    do return end
    local temp_list ={money={}, exp={}};
    local owner_rid;

    for _, info in pairs(attrib_info) do

        if is_object(info["ob"]) then

            if info["ob"]:query("ob_type") == OB_TYPE_USER then
                owner_rid = info["ob"]:query("rid");
            else
                owner_rid = info["ob"]:query("owner");
            end

            if owner_rid then

                if info["money"] then
                    temp_list.money[owner_rid] = true;
                elseif info["exp"] then
                    temp_list.exp[owner_rid] = true;
                end
            end
        end
    end

    --添加金钱奖励的次数
    for rid,_ in pairs(temp_list.money) do
        bonus_times_list[rid] = bonus_times_list[rid] or {};
        bonus_times_list[rid].money = bonus_times_list[rid].money or 0;
        bonus_times_list[rid].money = bonus_times_list[rid].money + 1;
    end

    --添加经验奖励的次数
    for rid,_ in pairs(temp_list.exp) do
        bonus_times_list[rid]     = bonus_times_list[rid] or {};
        bonus_times_list[rid].exp = bonus_times_list[rid].exp or 0;
        bonus_times_list[rid].exp = bonus_times_list[rid].exp + 1;
    end
end

function write_log(rid, online_time)

    local info = "";

    if bonus_times_list[rid] then
        info = table.tostring(bonus_times_list[rid]);
        bonus_times_list[rid] = nil;
    end

    LOG_D.to_log(LOG_TYPE_BONUS_TIMES, rid, tostring(online_time) , "", info);
end

--获得奖励信息
function calc_bonus(script, ...)
    if is_int(script) then
        if script > 0 then
            return (INVOKE_SCRIPT(script, ...));
        end
    else
        return (INVOKE_SCRIPT_ALIAS(script, ...));
    end
end

--获得物品奖励信息
function calc_property_bonus(cob, attacker_list, defenser_list)
    property_list = {};

    for _,defenser in pairs(defenser_list) do
        local script = defenser:query("property_bonus_script");

        --如果存在脚本编号，则取得该怪物的奖励
        if script and script > 1 then
            local property = calc_bonus(script, cob, defenser,
                                        attacker_list, defenser_list);

            tinsertvalues(property_list, property);
        end
    end

    return property_list;
end

--处理奖励问题，把物品奖励转化成属性
function pre_deal_bonus(bonus_info)
    bonus_info.attrib = bonus_info.attrib or {}
    local new_property = {}
    for _,v in ipairs(bonus_info.property or {}) do
        if v.class_id == GET_GOLD_ID() then
            table.insert(bonus_info.attrib, {gold = v.amount, ob = v.ob})
        elseif v.class_id == GET_STONE_ID() then
            table.insert(bonus_info.attrib, {stone = v.amount, ob = v.ob})
        else
            table.insert(new_property, v)
        end
    end
    bonus_info.property = new_property
end

function do_user_bonus(user, bonus_info, bonus_type, show_type)
    pre_deal_bonus(bonus_info)
    for _,v in ipairs(bonus_info.attrib) do
        if not v.ob then
            v.ob = user
        end
    end

    for _,v in ipairs(bonus_info.property) do
        if not v.ob then
            v.ob = user
        end
    end
    
    return do_bonus(bonus_info, bonus_type, show_type)
end

--执行奖励操作
--attrib和property均为数组
 --[=[bonus_info = {attrib   =  { { ob  = 奖励对象1,
                                    exp = 33;
                                    stone = 10;
                                  },
                                  { ob = 奖励对象2，
                                    stone=15,
                                  },
                                  ...
                                }

                    property  = { { ob = 奖励对象，
                                    class_id = 10001,
                                    amount =19,
                                    extra = {   -- 可选参数，宠物才有，传入获得信息
                                                obtain_way = ...,
                                                obtain_record = ...
                                                },
                                            }
                                    ....
                                  } ,

                                  ....
                                }
                    }   --]=]

function do_bonus(bonus_info, bonus_type, show_type)
    trace("bonus_info is %o", bonus_info)
    if not is_mapping(bonus_info) then
        return
    end

    --显示类型,
    if not show_type then
        show_type = BONUS_TYPE_SHOW;
    end

    local attrib_list = {};
    local property_list = {};

    local attribs = bonus_info["attrib"];
    --如果有属性，执行属性奖励操作
    if is_array(attribs) then
        --caculate_bonus_attrib_times(attribs);
        attrib_list = attrib_bonus(attribs, bonus_type);
    end

    local propertys = bonus_info["property"];

    --如果有物品则进行物品奖励
    if is_array(propertys) then
        --caculate_bonus_property_times(propertys)
        property_list = property_bonus(propertys, bonus_type);
    end
    trace("bonus_info[ property_list is %o \n", property_list)

    --向客户端发送奖励信息
    for rid, attrib in pairs(attrib_list) do
        local bonus = {};

        -- 属性
        if sizeof(attrib) > 0 then
            bonus["attrib"] = attrib;
        end

        -- 没有奖励，则不需要发送
        if sizeof(bonus) > 0 then
            local ob = find_object_by_rid(rid);
            if is_object(ob) then
                ob:send_message(MSG_BONUS, bonus, show_type);
                caculate_bonus_times_limit(ob, bonus_type);
            end
        end
    end

    --处理property_list中剩下的奖励
    for rid, property in pairs(property_list) do
        if sizeof(property) > 0 then
            local bonus  = {properties = property}
            local ob     = find_object_by_rid(rid);
            if is_object(ob) then
                ob:send_message(MSG_BONUS, bonus, show_type);
                caculate_bonus_times_limit(ob, bonus_type);
            end
        end
    end

    return true, property_list, attrib_list;
end

--检测玩家的奖励次数是否合法
function caculate_bonus_times_limit(user, bonus_type)
    do return end
    local times = bonus_times_limit_list[bonus_type] or 250;
    local user_bonus_times = user:query_temp("user_bonus_times") or {};
    local queue = user_bonus_times[bonus_type] or Queue.new();
    local cur_time = os.time();

    --将超过时间间隔的信息去除
    while Queue.getFirst(queue) and cur_time - Queue.getFirst(queue) > MAX_INTERVAL do
        Queue.popFirst(queue)
    end

    Queue.pushBack(queue, cur_time);

    --超过次数,冻结账号
    if Queue.getSize(queue) >= times then
        -- user:notify_dialog_ok($$[218],1);

        INTERNAL_COMM_D.send_message(AAA_ID, CMD_GS_FREEZE_ACCOUNT, user:query("account"));

        local queue_string = save_string(queue);
        INTERNAL_COMM_D.send_message(SPA_ID, CMD_GS_BONUS_EXCEPTION, user:query("account"),
                                    user:query("rid"), bonus_type, queue_string);
        --set_timer(5000,USER_D.user_logout, user);
        USER_D.user_logout(user);
        return;
    end

    user_bonus_times[bonus_type] = queue;
    user:set_temp("user_bonus_times", user_bonus_times);
end

function get_bonus_times_list()
    return bonus_times_list;
end

function get_limit_list()
    return bonus_times_limit_list;
end

-- 模块的入口执行
function create()
end

create();
