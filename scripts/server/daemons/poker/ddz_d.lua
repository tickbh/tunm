--roomd.lua
--Created by wugd
--负责斗地主相关的功能处理

--创建模块声明
DDZ_D = {}
setmetatable(DDZ_D, {__index = _G})
local _ENV = DDZ_D

--扑克类型
TYPE_ERROR                   = 0                                   --错误类型
TYPE_SINGLE                  = 1                                   --单牌类型
TYPE_DOUBLE                  = 2                                   --对牌类型
TYPE_THREE                   = 3                                   --三条类型
TYPE_SINGLE_LINE             = 4                                   --单连类型
TYPE_DOUBLE_LINE             = 5                                   --对连类型
TYPE_THREE_LINE              = 6                                   --三连类型
TYPE_THREE_LINE_TAKE_ONE     = 7                                   --三带一单
TYPE_THREE_LINE_TAKE_TWO     = 8                                   --三带一对
TYPE_FOUR_LINE_TAKE_ONE      = 9                                   --四带两单
TYPE_FOUR_LINE_TAKE_TWO      = 10                                  --四带两对
TYPE_BOMB_CARD               = 11                                  --炸弹类型
TYPE_MISSILE_CARD            = 12                                  --火箭类型

good_poker_data = {
    0x4E,0x4F,
    0x01,0x02,
    0x11,0x12,
    0x21,0x22,
    0x31,0x32,
    0x0A,0x0B,0x0C,0x0D,
    0x1A,0x1B,0x1C,0x1D,
    0x2A,0x2B,0x2C,0x2D,
    0x3A,0x3B,0x3C,0x3D
}

set_table_read_only(good_poker_data)

local function sort_card(card_a, card_b)
    local card_logic_a = get_card_logic_value(card_a)
    local card_logic_b = get_card_logic_value(card_b)
    if card_logic_a == card_logic_b then
        return card_a > card_b
    else
        return card_logic_a > card_logic_b
    end
end

--分牌，得出底牌，和排序
function get_new_game_poker()
    local new_poker_data = rand_sort_array(POKER_D.get_poker_data())
    local user_pokers = {}
    for i = 1, 51 do
        local index = i % 3
        if index == 0 then index = 3 end
        user_pokers[index] = user_pokers[index] or {}
        table.insert(user_pokers[index], new_poker_data[i])
    end
    local down_poker = { new_poker_data[52], new_poker_data[53], new_poker_data[54]}
    for i = 1, 3 do
        table.sort(user_pokers[i], sort_card)
    end
    table.sort(down_poker, sort_card)
    return user_pokers, down_poker
end

--获取扑克花色
function get_card_color(card)
    return bit32.band(card, 0xF0)
end

--获取扑克值
function get_card_value(card)
    return bit32.band(card, 0x0F)
end

function get_card_logic_value(card)
    local color = get_card_color(card)
    local value = get_card_value(card)
    assert(value > 0 and value < 16)
    if color == 0x40 then
        return value + 2
    elseif value <= 2 then
        return value + 13
    else
        return value
    end
end

local index_name = {"single", "double", "three", "four"}
function analyse_card_data(poker_list)
    local ret = {single_count = 0, single_list = {}, double_count = 0, double_list = {}, three_count = 0, three_list = {}, four_count = 0, four_list = {}}
    local idx = 1
    while idx <= #poker_list do
        local same_count = 1
        local logic_value = get_card_logic_value(poker_list[idx])
        if logic_value < 0 then
            return false
        end
        --搜索同牌
        for i=idx+1,#poker_list do
            if get_card_logic_value(poker_list[i]) ~= logic_value then
                break
            end
            same_count = same_count + 1
        end
        local name = index_name[same_count]
        if not name then
            return false
        end
        local coun_name = string.format("%s_count", name)
        local list_name = string.format("%s_list", name)
        ret[coun_name] = ret[coun_name] + 1
        for i=1,same_count do
            table.insert(ret[list_name], poker_list[idx + i - 1])
        end
        idx = idx + same_count
    end
    return true, ret
end

function get_card_type(poker_list)
    if not poker_list then
        return TYPE_ERROR
    end
    local len = #poker_list
    if len == 0 then
        return TYPE_ERROR
    elseif len == 1 then
        return TYPE_SINGLE
    elseif len == 2 then
        if poker_list[1] == 0x4F and poker_list[2] == 0x4E then
            return TYPE_MISSILE_CARD
        elseif get_card_logic_value(poker_list[1]) == get_card_logic_value(poker_list[2]) then
            return TYPE_DOUBLE
        else
            return TYPE_ERROR
        end
    end

    local success, result = analyse_card_data(poker_list)
    if not success then
        return TYPE_ERROR
    end

    if result.four_count > 0 then
        if result.four_count == 1 then
            if len == 4 then return TYPE_BOMB_CARD, result end
            if len == 6 and result.single_count == 2 then return TYPE_FOUR_LINE_TAKE_ONE, result end
            if len == 8 and result.double_count == 2 then return TYPE_FOUR_LINE_TAKE_TWO, result end
        end

        --不在以四张出牌，可能3张连带1根，或者3连带两对
        if #poker_list % 4 ~= 0 and #poker_list % 5 ~= 0 then
            return TYPE_ERROR
        end

        local function split_with_three(idx)
            result.three_count = result.three_count + 1
            table.insert(result.three_list, result.four_list[idx * 4])
            table.insert(result.three_list, result.four_list[idx * 4 - 1])
            table.insert(result.three_list, result.four_list[idx * 4 - 2])
            result.single_count = result.single_count + 1
            table.insert(result.single_list, result.four_list[idx * 4 - 3])
            table.sort(result.three_list, sort_card)
            table.sort(result.single_list, sort_card)
        end

        local function split_with_two(idx)
            result.double_count = result.double_count + 1
            table.insert(result.double_list, result.four_list[idx * 4])
            table.insert(result.double_list, result.four_list[idx * 4 - 1])
            result.double_count = result.double_count + 1
            table.insert(result.double_list, result.four_list[idx * 4 - 2])
            table.insert(result.double_list, result.four_list[idx * 4 - 3])
            table.sort(result.double_list, sort_card)
        end

        local function split_with_one(idx)
            result.single_count = result.single_count + 1
            table.insert(result.single_list, result.four_list[idx * 4])
            table.insert(result.single_list, result.four_list[idx * 4 - 1])
            table.insert(result.single_list, result.four_list[idx * 4 - 2])
            table.insert(result.single_list, result.four_list[idx * 4 - 3])
            table.sort(result.single_list, sort_card)
        end

        --两个炸弹以上，只有两种情况，5连带带5根，或者是3连带带6根
        if #poker_list == 20 then
            if result.three_count + result.four_count < 5 then
                return TYPE_ERROR
            end
            if result.three_count + result.four_count == 5 then
                for i=1,result.four_count do
                    split_with_three(i)
                end
                result.four_count = 0
                result.four_list = {}
            else
                return TYPE_ERROR
            end
        else
            if #poker_list % 5 == 0 then
                for i=1,result.four_count do
                    split_with_two(i)
                end
                result.four_count = 0
                result.four_list = {}
            else
                for i=1,result.four_count do
                    if result.three_count == #poker_list / 4 then
                        split_with_one(i)
                    else
                        split_with_three(i)
                    end
                end
                result.four_count = 0
                result.four_list = {}
            end
        end
    end

    if result.three_count > 0 then
        if result.three_count == 1 and len == 3 then return TYPE_THREE end
        if result.three_count > 1 then
            local card_data = result.three_list[1]
            local first_logic_value = get_card_logic_value(card_data)
            if first_logic_value >= 15 then
                return TYPE_ERROR
            end
            --连牌判断
            for i=1,result.three_count -1 do
                local sub_card_data = result.three_list[1 + i * 3]
                if first_logic_value ~= get_card_logic_value(sub_card_data) + i then
                    return TYPE_ERROR
                end
            end
        end

        if result.three_count * 3 == len then return TYPE_THREE_LINE, result end
        if result.three_count * 4 == len then return TYPE_THREE_LINE_TAKE_ONE, result end
        if result.three_count * 5 == len and result.double_count == result.three_count then return TYPE_THREE_LINE_TAKE_TWO, result end

        return TYPE_ERROR
    end

    if result.double_count >= 3 then
        local card_data = result.double_list[1]
        local first_logic_value = get_card_logic_value(card_data)
        if first_logic_value >= 15 then
            return TYPE_ERROR
        end
        --连牌判断
        for i=1,result.double_count -1 do
            local sub_card_data = result.double_list[1 + i * 2]
            if first_logic_value ~= get_card_logic_value(sub_card_data) + i then
                return TYPE_ERROR
            end
        end

        if result.double_count * 2 == len then return TYPE_DOUBLE_LINE, result end

        return TYPE_ERROR
    end

    if result.single_count >= 5 then
        local card_data = result.single_list[1]
        local first_logic_value = get_card_logic_value(card_data)
        if first_logic_value >= 15 then
            return TYPE_ERROR
        end
        --连牌判断
        for i=1,result.single_count -1 do
            local sub_card_data = result.single_list[1 + i]
            if first_logic_value ~= get_card_logic_value(sub_card_data) + i then
                return TYPE_ERROR
            end
        end

        return TYPE_SINGLE_LINE, result
    end
    return TYPE_ERROR
end

function compare_card(first_poker_list, next_poker_list)
    local next_type, next_result = get_card_type(next_poker_list)
    local first_type, first_result = get_card_type(first_poker_list)

    if next_type == TYPE_ERROR then return false end
    if next_type == TYPE_MISSILE_CARD then return true end
    if first_type == TYPE_MISSILE_CARD then return false end

    if first_type ~= TYPE_BOMB_CARD and next_type == TYPE_BOMB_CARD then return true end
    if first_type == TYPE_BOMB_CARD and next_type ~= TYPE_BOMB_CARD then return false end

    if first_type ~= next_type or #first_poker_list ~= #next_poker_list then return false end
    if next_type == TYPE_SINGLE or next_type == TYPE_DOUBLE or next_type == TYPE_THREE
        or next_type == TYPE_SINGLE_LINE or next_type == TYPE_DOUBLE_LINE or next_type == TYPE_THREE_LINE or next_type == TYPE_BOMB_CARD then
        local first_logic_value = get_card_logic_value(first_poker_list[1])
        local next_logic_value = get_card_logic_value(next_poker_list[1])
        return next_logic_value > first_logic_value
    elseif next_type == TYPE_THREE_LINE_TAKE_ONE or next_type == TYPE_THREE_LINE_TAKE_TWO then
        local first_logic_value = get_card_logic_value(first_result.three_list[1])
        local next_logic_value = get_card_logic_value(next_result.three_list[1])
        return next_logic_value > first_logic_value
    elseif next_type == CT_FOUR_LINE_TAKE_ONE or next_type == CT_FOUR_LINE_TAKE_TWO then
        local first_logic_value = get_card_logic_value(first_result.four_list[1])
        local next_logic_value = get_card_logic_value(next_result.four_list[1])
        return next_logic_value > first_logic_value
    end
    return false
end

-- function is_contain(poker_list, sub_poker_list)
--     local find_idx = 1
--     for _,poker in ipairs(sub_poker_list) do
--         local is_find = false
--         for i=find_idx,#poker_list do
--             if poker_list[i] == poker then
--                 find_idx = i + 1
--                 is_find = true
--                 break
--             end
--         end
--         if not is_find then
--             return false
--         end
--     end
--     return true
-- end

-- function sub_poker(poker_list, sub_poker_list)
--     if not is_contain(poker_list, sub_poker_list) then
--         return false
--     end
--     local new_poker_list = {}
--     local find_idx = 1
--     for _, poker in ipairs(poker_list) do
--         local is_find = false
--         for i=find_idx,#sub_poker_list do
--             if sub_poker_list[i] == poker then
--                 find_idx = i + 1
--                 is_find = true
--                 break
--             end

--         end
--         if not is_find then
--             table.insert(new_poker_list, poker)
--         end
--     end

--     return true, new_poker_list
-- end

function is_contain(poker_list, sub_poker_list)
    return is_sub_array(poker_list, sub_poker_list)
end

function sub_poker(poker_list, sub_poker_list)
    local success, new_poker_list = sub_array(poker_list, sub_poker_list)
    if not success then
        return false
    end
    table.sort(new_poker_list, sort_card)
    return true, new_poker_list
end

function resort_poker(poker_list)
    table.sort(poker_list, sort_card)
    return poker_list
end

function get_double_count(poker_list, need_num)
    local success, has_result = analyse_card_data(poker_list)
    local result_list = {}
    if success then
        for i=has_result.double_count,1,-1 do
            table.insert(result_list, has_result.double_list[i * 2])
            table.insert(result_list, has_result.double_list[i * 2 -1])
            if #result_list == need_num * 2 then
                return result_list
            end
        end
        for i=has_result.three_count,1,-1 do
            table.insert(result_list, has_result.three_list[i * 3])
            table.insert(result_list, has_result.three_list[i * 3 -1])
            if #result_list == need_num * 2 then
                return result_list
            end
        end
        for i=has_result.four_count,1,-1 do
            table.insert(result_list, has_result.four_list[i * 4])
            table.insert(result_list, has_result.four_list[i * 4 - 1])
            if #result_list == need_num * 2 then
                return result_list
            end
            table.insert(result_list, has_result.four_list[i * 4 - 2])
            table.insert(result_list, has_result.four_list[i * 4 - 3])
            if #result_list == need_num * 2 then
                return result_list
            end
        end
    end
    return {}
end


--计算可大过上家的牌，为提示功能使用
local function calc_tip_poker(poker_list, pre_poker_list)
    local out_list = {}
    if #poker_list == 0 then
        return out_list
    end
    local card_type, pre_result = get_card_type(pre_poker_list)
    if card_type == TYPE_ERROR then
        local last_poker = poker_list[#poker_list]
        table.insert(out_list, last_poker)
        --搜索最小的牌，尽可能的组牌
        for i=#poker_list - 1,1,-1 do
            if last_poker == 0x4E and poker_list[i] == 0x4F then
                table.insert(out_list, poker_list[i])
            elseif get_card_logic_value(last_poker) == get_card_logic_value(poker_list[i]) then
                table.insert(out_list, poker_list[i])
            else
                break
            end
        end
        return out_list
    end
    if card_type == TYPE_MISSILE_CARD then
        return out_list
    end
    local success, result = analyse_card_data(poker_list)
    if not success then
        return out_list
    end

    local function check_bomb_list(pre_bomb_value)
        pre_bomb_value = pre_bomb_value or 0
        for i=#result.four_list, 1, -1 do
            if get_card_logic_value(result.four_list[i]) > pre_bomb_value then
                table.insert(out_list, result.four_list[i])
            end
            if #out_list == 4 then
                return true
            end
        end

        --检测王炸
        if poker_list[1] == 0x4F and poker_list[2] == 0x4E then
            table.insert(out_list, poker_list[1])
            table.insert(out_list, poker_list[2])
            return true
        end

        return false
    end

    local function check_list_accord(list, pre_logic_value, need_num)
        for i=#list, 1, -1 do
            if get_card_logic_value(list[i]) > pre_logic_value then
                table.insert(out_list, list[i])
            end
            if #out_list == need_num then
                return true
            end
        end
        return false
    end

    local function check_three_line()
        local pre_single_line_num = #pre_result.three_list
        local single_line_start = get_card_logic_value(pre_result.three_list[#pre_result.three_list])
        for i=#poker_list,1,-1 do
            local cur_logic_value = get_card_logic_value(poker_list[i])
            if cur_logic_value > single_line_start and cur_logic_value < 15 then
                if #out_list == 0 then
                    table.insert(out_list, poker_list[i])
                else
                    local step = cur_logic_value - get_card_logic_value(out_list[#out_list])
                    if step > 1 then
                        out_list = {}
                    else
                        --已添加三张牌整倍数
                        if #out_list % 3 == 0 then
                            if step == 1 then
                                table.insert(out_list, poker_list[i])
                            end
                        else
                            if step > 0 then
                                out_list = {}
                            else
                                table.insert(out_list, poker_list[i])
                                if #out_list == pre_single_line_num then
                                    return true
                                end
                            end

                        end

                    end
                end
            end
        end
        return false
    end

    if card_type == TYPE_SINGLE then
        local pre_logic_value = get_card_logic_value(pre_poker_list[1])
        for i=#poker_list,1,-1 do
            if get_card_logic_value(poker_list[i]) > pre_logic_value then
                table.insert(out_list, poker_list[i])
                return out_list
            end
        end
        check_bomb_list()
        return out_list
    elseif card_type ==  TYPE_DOUBLE then
        local pre_logic_value = get_card_logic_value(pre_poker_list[1])
        if check_list_accord(result.double_list, pre_logic_value, 2) then
            return out_list
        end
        if check_list_accord(result.three_list, pre_logic_value, 2) then
            return out_list
        end
        if check_list_accord(result.four_list, pre_logic_value, 2) then
            return out_list
        end
        check_bomb_list()
        return out_list
    elseif card_type ==  TYPE_THREE then
        local pre_logic_value = get_card_logic_value(pre_poker_list[1])
        if check_list_accord(result.three_list, pre_logic_value, 3) then
            return out_list
        end
        if check_list_accord(result.four_list, pre_logic_value, 3) then
            return out_list
        end
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_SINGLE_LINE then
        local pre_single_line_num = #pre_poker_list
        local single_line_start = get_card_logic_value(pre_poker_list[#pre_poker_list])
        for i=#poker_list,1,-1 do
            local cur_logic_value = get_card_logic_value(poker_list[i])
            if cur_logic_value > single_line_start and cur_logic_value < 15 then
                if #out_list == 0 then
                    table.insert(out_list, poker_list[i])
                else
                    local step = cur_logic_value - get_card_logic_value(out_list[#out_list])
                    if step > 1 then
                        out_list = {}
                    elseif step == 1 then
                        table.insert(out_list, poker_list[i])
                        if #out_list == pre_single_line_num then
                            return out_list
                        end
                    end
                end
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_DOUBLE_LINE then
        local pre_single_line_num = #pre_poker_list
        local single_line_start = get_card_logic_value(pre_poker_list[#pre_poker_list])
        for i=#poker_list,1,-1 do
            local cur_logic_value = get_card_logic_value(poker_list[i])
            if cur_logic_value > single_line_start and cur_logic_value < 15 then
                if #out_list == 0 then
                    table.insert(out_list, poker_list[i])
                else
                    local step = cur_logic_value - get_card_logic_value(out_list[#out_list])
                    if step > 1 then
                        out_list = {}
                    else
                        --已添加双张牌
                        if #out_list % 2 == 0 then
                            if step == 1 then
                                table.insert(out_list, poker_list[i])
                            end
                        else
                            if step > 0 then
                                out_list = {}
                            else
                                table.insert(out_list, poker_list[i])
                                if #out_list == pre_single_line_num then
                                    return out_list
                                end
                            end

                        end

                    end
                end
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_THREE_LINE then
        if check_three_line() then
            return out_list
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_THREE_LINE_TAKE_ONE then
        local need_three_num = #pre_poker_list / 4
        if #result.three_list >= need_three_num and #poker_list >= #pre_poker_list then
            if check_three_line() then
                local success, has_poker_list = sub_poker(poker_list, out_list)
                for i=#has_poker_list,1,-1 do
                    table.insert(out_list, has_poker_list[i])
                    if #out_list == #pre_poker_list then
                        return out_list
                    end
                end
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_THREE_LINE_TAKE_TWO then
        local need_three_num = #pre_poker_list / 5
        if #result.three_list >= need_three_num and #poker_list >= #pre_poker_list then
            if check_three_line() then
                local success, has_poker_list = sub_poker(poker_list, out_list)
                local double_list = get_double_count(has_poker_list, need_three_num)
                if #double_list > 0 then
                    append_to_array(out_list, double_list)
                    return out_list
                end
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_FOUR_LINE_TAKE_ONE then
        local pre_four_value = get_card_logic_value(pre_result.four_list[1])
        for i=#result.four_list, 1, -1 do
            if get_card_logic_value(result.four_list[i]) > pre_four_value then
                table.insert(out_list, result.four_list[i])
            end
            if #out_list == 4 then
                break
            end
        end
        if #out_list == 4 then
            local success, has_poker_list = sub_poker(poker_list, out_list)
            if #has_poker_list > 1 then
                table.insert(out_list, has_poker_list[#has_poker_list])
                table.insert(out_list, has_poker_list[#has_poker_list - 1])
                return out_list
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_FOUR_LINE_TAKE_TWO then
        local pre_four_value = get_card_logic_value(pre_result.four_list[1])
        for i=#result.four_list, 1, -1 do
            if get_card_logic_value(result.four_list[i]) > pre_four_value then
                table.insert(out_list, result.four_list[i])
            end
            if #out_list == 4 then
                break
            end
        end
        if #out_list == 4 then
            local success, has_poker_list = sub_poker(poker_list, out_list)
            local double_list = get_double_count(has_poker_list, 2)
            if #double_list > 0 then
                append_to_array(out_list, double_list)
                return out_list
            end
        end
        out_list = {}
        check_bomb_list()
        return out_list
    elseif card_type == TYPE_BOMB_CARD then
        check_bomb_list(get_card_logic_value(pre_result.four_list[1]))
        return out_list
    end

    return out_list

end

function sort_calc_tip_poker(poker_list, pre_poker_list)
    local out_list = calc_tip_poker(poker_list, pre_poker_list)
    table.sort(out_list, sort_card)
    return out_list
end

function calc_pea_change(pea_amount_list, idx, lord_idx, multi_num, is_win)
    local base_pea = multi_num * 10
    local is_lord = idx == lord_idx
    local one_cost = 220
    local sum = 0
    local lord_pea = pea_amount_list[lord_idx]
    if is_win == 1 then
        if is_lord then
            local per_max_add = lord_pea / 2
            for i=1,3 do
                if i ~= lord_idx then
                    sum = sum + calc_table_min({base_pea, per_max_add, math.max(pea_amount_list[i] - one_cost, 0)})
                end
            end
        else
            local per_max_add = (lord_pea - one_cost) / 2
            sum = sum + calc_table_min({base_pea, per_max_add, math.max(pea_amount_list[idx], 0)})
        end
    else
        if is_lord then
            for i=1,3 do
                if i ~= lord_idx then
                    sum = sum - calc_table_min({base_pea, (lord_pea - one_cost) / 2, math.max(pea_amount_list[i], 0)})
                end
            end
        else
            sum = - calc_table_min({base_pea, lord_pea / 2, math.max(pea_amount_list[idx] - one_cost, 0)})
        end
    end
    sum = sum - one_cost
    return sum

end


--Test Func
local function test_sort()
    local card_ori = {0x0B, 0x01, 0x08, 0x02, 0x4E}
    table.sort(card_ori, sort_card)
    assert_eq(card_ori, {0x4E, 0x02, 0x01, 0x0B, 0x08}, "array error")
end

local function test_pea_change()
    local function check_pea_change(pea_amount_list, idx, lord_idx, multi_num, is_win, result)
        local ret = calc_pea_change(pea_amount_list, idx, lord_idx, multi_num, is_win)
        assert(ret == result)    
    end
    
    check_pea_change({1000, 1000, 1000}, 1, 1, 15, 1, 80)
    check_pea_change({1000, 1000, 1000}, 1, 1, 150, 1, 780)

    check_pea_change({1000, 1000, 1000}, 1, 2, 15, 1, -70)
    check_pea_change({1000, 1000, 1000}, 1, 2, 150, 1, 170)

    check_pea_change({1000, 1000, 1000}, 1, 1, 15, 0, -520)
    check_pea_change({1000, 1000, 1000}, 1, 1, 150, 0, -1000)

    check_pea_change({1000, 1000, 1000}, 1, 2, 15, 0, -370)
    check_pea_change({1000, 1000, 1000}, 1, 2, 150, 0, -720)
end

local function check_poker_type(poker_list, poker_type)
    table.sort(poker_list, sort_card)
    local real_type = get_card_type(poker_list)
    assert(real_type == poker_type)
end

local function test_get_type()
    --TYPE_SINGLE
    check_poker_type({0x01}, TYPE_SINGLE)
    check_poker_type({0x03}, TYPE_SINGLE)
    check_poker_type({0x0D}, TYPE_SINGLE)
    check_poker_type({0x4E}, TYPE_SINGLE)

    --TYPE_DOUBLE
    check_poker_type({0x01, 0x11}, TYPE_DOUBLE)
    check_poker_type({0x06, 0x16}, TYPE_DOUBLE)
    check_poker_type({0x08, 0x28}, TYPE_DOUBLE)
    check_poker_type({0x29, 0x39}, TYPE_DOUBLE)

    --TYPE_THREE
    check_poker_type({0x01, 0x11, 0x21}, TYPE_THREE)
    check_poker_type({0x06, 0x16, 0x26}, TYPE_THREE)
    check_poker_type({0x08, 0x28, 0x38}, TYPE_THREE)
    check_poker_type({0x19, 0x29, 0x39}, TYPE_THREE)

    --TYPE_SINGLE_LINE
    check_poker_type({0x03, 0x04, 0x05, 0x06, 0x07}, TYPE_SINGLE_LINE)
    check_poker_type({0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C}, TYPE_SINGLE_LINE)
    check_poker_type({0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x01}, TYPE_SINGLE_LINE)

    --TYPE_DOUBLE_LINE
    check_poker_type({0x03, 0x13, 0x04, 0x24, 0x05, 0x35}, TYPE_DOUBLE_LINE)
    check_poker_type({0x05, 0x15, 0x06, 0x26, 0x07, 0x37}, TYPE_DOUBLE_LINE)
    check_poker_type({0x05, 0x15, 0x06, 0x26, 0x07, 0x37, 0x08, 0x28, 0x09, 0x39}, TYPE_DOUBLE_LINE)

    --TYPE_THREE_LINE
    check_poker_type({0x03, 0x13, 0x23, 0x14, 0x24, 0x34}, TYPE_THREE_LINE)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21}, TYPE_THREE_LINE)

    --TYPE_THREE_LINE_TAKE_ONE
    check_poker_type({0x03, 0x13, 0x23, 0x14, 0x24, 0x34, 0x4E, 0x4F}, TYPE_THREE_LINE_TAKE_ONE)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x13}, TYPE_THREE_LINE_TAKE_ONE)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x04}, TYPE_THREE_LINE_TAKE_ONE)
    check_poker_type({0x0C, 0x1C, 0x2C, 0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x04, 0x05}, TYPE_THREE_LINE_TAKE_ONE)
    check_poker_type({0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x33, 0x05}, TYPE_THREE_LINE_TAKE_ONE)

    --TYPE_THREE_LINE_TAKE_TWO
    check_poker_type({0x03, 0x13, 0x23, 0x14, 0x24, 0x34, 0x05, 0x15, 0x16, 0x26}, TYPE_THREE_LINE_TAKE_TWO)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x13, 0x06, 0x26}, TYPE_THREE_LINE_TAKE_TWO)
    check_poker_type({0x0C, 0x1C, 0x2C, 0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x13, 0x04, 0x14, 0x05, 0x15}, TYPE_THREE_LINE_TAKE_TWO)
    check_poker_type({0x03, 0x13, 0x23, 0x14, 0x24, 0x34, 0x05, 0x15, 0x25, 0x35}, TYPE_THREE_LINE_TAKE_TWO)

    --TYPE_FOUR_LINE_TAKE_ONE
    check_poker_type({0x03, 0x13, 0x23, 0x33, 0x01, 0x02}, TYPE_FOUR_LINE_TAKE_ONE)
    check_poker_type({0x04, 0x14, 0x24, 0x34, 0x03, 0x05}, TYPE_FOUR_LINE_TAKE_ONE)


    --TYPE_FOUR_LINE_TAKE_TWO
    check_poker_type({0x03, 0x13, 0x23, 0x33, 0x01, 0x11, 0x02, 0x22}, TYPE_FOUR_LINE_TAKE_TWO)

    --TYPE_BOMB_CARD
    check_poker_type({0x03, 0x13, 0x23, 0x33}, TYPE_BOMB_CARD)
    check_poker_type({0x04, 0x14, 0x24, 0x34}, TYPE_BOMB_CARD)

    --TYPE_MISSILE_CARD
    check_poker_type({0x4E, 0x4F}, TYPE_MISSILE_CARD)

    --TYPE_ERROR
    check_poker_type({0x03, 0x04, 0x05, 0x06}, TYPE_ERROR)
    check_poker_type({0x0A, 0x0B, 0x0C, 0x0D, 0x01, 0x02}, TYPE_ERROR)
    check_poker_type({0x05, 0x15, 0x06, 0x26}, TYPE_ERROR)
    check_poker_type({0x05, 0x15, 0x06, 0x26, 0x07, 0x37, 0x08, 0x28, 0x09, 0x39, 0x0A}, TYPE_ERROR)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x33}, TYPE_ERROR)
    check_poker_type({0x0D, 0x1D, 0x2D, 0x01, 0x11, 0x21, 0x03, 0x04, 0x05}, TYPE_ERROR)
    check_poker_type({0x03, 0x13, 0x23, 0x33, 0x01, 0x02, 0x01}, TYPE_ERROR)


    

    local function check_contain(poker_list, sub_poker_list)
        table.sort(poker_list, sort_card)
        table.sort(sub_poker_list, sort_card)
        assert(is_contain(poker_list, sub_poker_list) == true)
    end
    check_contain({0x03, 0x14, 0x16}, {0x03, 0x16})

    local function check_sub(poker_list, sub_poker_list, result_poker_list)
        table.sort(poker_list, sort_card)
        table.sort(sub_poker_list, sort_card)
        table.sort(result_poker_list, sort_card)

        local success, new_poker_list = sub_poker(poker_list, sub_poker_list)
        assert(success, "must is sub poker")
        assert_eq(new_poker_list, result_poker_list)
    end

    check_sub({0x03, 0x14, 0x16}, {0x03, 0x16}, {0x14})
    check_sub({0x03, 0x14, 0x16, 0x13}, {0x03, 0x13}, {0x14, 0x16})

    local function check_compare_card(first_poker_list, next_poker_list)
        table.sort(first_poker_list, sort_card)
        table.sort(next_poker_list, sort_card)

        assert(compare_card(first_poker_list, next_poker_list) == true)
    end

    check_compare_card({0x03}, {0x04})
    check_compare_card({0x03, 0x13}, {0x04, 0x14})


    local function check_calc_tip_poker(poker_list, pre_poker_list, result_list)
        table.sort(poker_list, sort_card)
        table.sort(pre_poker_list, sort_card)
        table.sort(result_list, sort_card)
        
        local out_list = sort_calc_tip_poker(poker_list, pre_poker_list)
        assert_eq(out_list, result_list, "check_calc_tip_poker error")
    end



    -- calc none tip
    check_calc_tip_poker({0x03, 0x04, 0x05}, {}, {0x03})
    check_calc_tip_poker({0x03, 0x13, 0x04, 0x05}, {}, {0x03, 0x13})

    -- calc TYPE_SINGLE tip
    check_calc_tip_poker({0x03, 0x04, 0x05}, {0x03}, {0x04})
    check_calc_tip_poker({0x03, 0x04, 0x05}, {0x06}, {})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x04, 0x05}, {0x06}, {0x03, 0x13, 0x23, 0x33})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x04, 0x05, 0x06, 0x16, 0x26, 0x36}, {0x4F}, {0x03, 0x13, 0x23, 0x33})

    -- calc TYPE_DOUBLE tip
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x15}, {0x03, 0x13}, {0x05, 0x15})
    --拆四条
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x08, 0x18, 0x28, 0x38}, {0x06, 0x16}, {0x08, 0x18})
    --拆三条
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x08, 0x18, 0x28}, {0x06, 0x16}, {0x08, 0x18})
    --优先二条
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x08, 0x18, 0x28, 0x09, 0x19}, {0x06, 0x16}, {0x09, 0x19})
    check_calc_tip_poker({0x03, 0x04, 0x05}, {0x06, 0x16}, {})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x04, 0x05}, {0x06, 0x16}, {0x03, 0x13, 0x23, 0x33})

    -- calc TYPE_THREE tip
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x15, 0x25}, {0x03, 0x13, 0x23}, {0x05, 0x15, 0x25})
    --拆四条
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x08, 0x18, 0x28, 0x38}, {0x06, 0x16, 0x26}, {0x08, 0x18, 0x28})
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x08, 0x18, 0x28, 0x38, 0x09, 0x19, 0x29}, {0x06, 0x16, 0x26}, {0x09, 0x19, 0x29})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x04, 0x05}, {0x06, 0x16, 0x26}, {0x03, 0x13, 0x23, 0x33})

    -- calc TYPE_SINGLE_LINE tip
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x15, 0x25}, {0x03, 0x04, 0x05, 0x06, 0x07}, {0x04, 0x05, 0x06, 0x07, 0x08})
    check_calc_tip_poker({0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x15, 0x25}, {0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09}, {0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02}, {0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x01}, {})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x01, 0x02}, {0x09, 0x0A, 0x0B, 0x0C, 0x0D}, {0x0A, 0x0B, 0x0C, 0x0D, 0x01})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x01}, {0x4E, 0x4F})

    -- calc TYPE_DOUBLE_LINE tip
    check_calc_tip_poker({0x03, 0x13, 0x04, 0x14, 0x05, 0x15, 0x06, 0x16}, {0x03, 0x13, 0x04, 0x14, 0x05, 0x15}, {0x04, 0x14, 0x05, 0x15, 0x06, 0x16})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02}, {0x03, 0x13, 0x04, 0x14, 0x05, 0x15}, {})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x03, 0x13, 0x04, 0x14, 0x05, 0x15}, {0x4E, 0x4F})

    -- calc TYPE_THREE_LINE tip
    check_calc_tip_poker({0x03, 0x13, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24}, {0x04, 0x14, 0x24, 0x15, 0x25, 0x35})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24}, {})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24}, {0x4E, 0x4F})


    -- calc TYPE_THREE_LINE_TAKE_ONE tip
    check_calc_tip_poker({0x03, 0x13, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x05}, {0x03, 0x13, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35})
    check_calc_tip_poker({0x03, 0x13, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x33, 0x05}, {0x03, 0x13, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x05}, {})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x05}, {0x4E, 0x4F})


    -- calc TYPE_THREE_LINE_TAKE_TWO tip
    check_calc_tip_poker({0x03, 0x13, 0x06, 0x16, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x16, 0x05, 0x15}, {0x03, 0x13, 0x06, 0x16, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35})
    check_calc_tip_poker({0x03, 0x13, 0x06, 0x16, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x05, 0x15, 0x25, 0x35}, {0x03, 0x13, 0x06, 0x16, 0x04, 0x14, 0x24, 0x15, 0x25, 0x35})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x16, 0x05, 0x15}, {})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x03, 0x13, 0x23, 0x04, 0x14, 0x24, 0x06, 0x16, 0x05, 0x15}, {0x4E, 0x4F})



    -- calc TYPE_FOUR_LINE_TAKE_ONE tip
    check_calc_tip_poker({0x06, 0x16, 0x26, 0x36, 0x13, 0x15}, {0x04, 0x14, 0x24, 0x34, 0x03, 0x05}, {0x06, 0x16, 0x26, 0x36, 0x13, 0x15})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x17, 0x15}, {0x04, 0x14, 0x24, 0x34, 0x03, 0x05}, {0x03, 0x13, 0x23, 0x33})


    -- calc TYPE_FOUR_LINE_TAKE_TWO tip
    check_calc_tip_poker({0x06, 0x16, 0x26, 0x36, 0x23, 0x33, 0x25, 0x35}, {0x04, 0x14, 0x24, 0x34, 0x03, 0x13, 0x05, 0x15}, {0x06, 0x16, 0x26, 0x36, 0x23, 0x33, 0x25, 0x35})
    check_calc_tip_poker({0x03, 0x13, 0x23, 0x33, 0x17, 0x15}, {0x04, 0x14, 0x24, 0x34, 0x03, 0x13, 0x05, 0x15}, {0x03, 0x13, 0x23, 0x33})

    -- calc TYPE_BOMB_CARD tip
    check_calc_tip_poker({0x04, 0x14, 0x24, 0x34}, {0x03, 0x13, 0x23, 0x33}, {0x04, 0x14, 0x24, 0x34})
    check_calc_tip_poker({0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0A, 0x02, 0x4E, 0x4F}, {0x03, 0x13, 0x23, 0x33}, {0x4E, 0x4F})

end

if ENABLE_TEST then
    test_sort()
    test_get_type()
    test_pea_change()
end