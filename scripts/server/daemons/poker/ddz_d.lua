--roomd.lua
--Created by wugd
--负责斗地主相关的功能处理

--创建模块声明
DDZ_D = {}
setmetatable(DDZ_D, {__index = _G})
local _ENV = DDZ_D

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

local card_big = {[1] = 1, [2] = 1, [0xe] = 1, [0xf] = 1}
local function sort_card(card_a, card_b)
    local card_mod_a = card_a % 16
    local card_mod_b = card_b % 16
    if card_big[card_mod_a] ~= card_big[card_mod_b] then
        return (card_big[card_mod_a] or 0) > (card_big[card_mod_b] or 0)
    else
        if card_mod_a ~= card_mod_b then
            return card_mod_a > card_mod_b
        else
            return card_a > card_b
        end
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
    trace("user_pokers = %o, down_poker = %o", user_pokers, down_poker)
    return user_pokers, down_poker
end

--Test Func
local function test_sort()
    local card_ori = {0x0B, 0x01, 0x08, 0x02, 0x4E}
    table.sort(card_ori, sort_card)
    assert_eq(card_ori, {0x4E, 0x02, 0x01, 0x0B, 0x08}, "array error")
end

if ENABLE_TEST then
    test_sort()
end