
function connect(account, password)
    LOGIN_D.login(account, password)
end

function c()
    connect("aa", "bb")
end

function c1()
    connect("aa1", "bb1")
end

function c2()
    connect("aa2", "bb2")
end

local function command_send_message(...)
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(...)
end

local function add_attrib(field, amount)
    command_send_message(CMD_COMMON_OP, {oper = "add", field = field, amount = amount})
end

local function cost_attrib(field, amount)
    command_send_message(CMD_COMMON_OP, {oper = "cost", field = field, amount = amount})
end

function add_gold(amount)
    add_attrib("gold", amount)
end

function cost_gold(amount)
    cost_attrib("gold", amount)
end

function add_stone(amount)
    add_attrib("stone", amount)
end

function cost_stone(amount)
    cost_attrib("stone", amount)
end

function add_exp(amount)
    add_attrib("exp", amount)
end

function add_item(class_id, amount)
    amount = amount or 1
    command_send_message(CMD_COMMON_OP, {oper = "add_item", class_id = class_id, amount = amount})
end

function show_items()
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end

    local items = user:get_page_carry(PAGE_ITEM)
    table.sort(items, function(itema, itemb)
        local _, posa = READ_POS(itema:query("pos"))
        local _, posb = READ_POS(itemb:query("pos"))
        if posa == nil or posb == nil then
            return false
        end
        return posa < posb
    end)
    trace("您拥有的位置如下：")
    for _,item in ipairs(items) do
        trace("位置:%s, 物品rid:%s, 物品名称:%s, 物品数量:%d", item:query("pos"), item:query("rid"), item:query("name"), item:query("amount"))
    end
end

function show_equips()
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    local equips = user:get_page_carry(PAGE_EQUIP)
    table.sort(equips, function(equipa, equipb)
        local _, posa = READ_POS(equipa:query("pos"))
        local _, posb = READ_POS(equipb:query("pos"))
        if posa == nil or posb == nil then
            return false
        end
        return posa < posb
    end)
    trace("您拥有的位置如下：")
    for _,equip in ipairs(equips) do
        trace("位置:%s, 物品rid:%s, 物品名称:%s, 物品数量:%d, 等级:%d", equip:query("pos"), equip:query("rid"), equip:query("name"), equip:query("amount"), equip:query("lv"))
    end
end

function sale_object(rid, amount)
    amount = amount or 1
    command_send_message(CMD_SALE_OBJECT, {rid = rid, amount = amount})
end

function send_chat(content)
    command_send_message(CMD_CHAT, CHAT_CHANNEL_WORLD, {send_content = content})
end

function enter_room(room_name)
    room_name = room_name or "ddz1"
    command_send_message(CMD_ENTER_ROOM, {room_name = room_name})
end

--桌号，进入方法(游戏(game)，旁观(look))
function enter_desk(idx, method)
    command_send_message(CMD_ROOM_MESSAGE, "enter_desk", {idx = idx, enter_method = method})
end

function leave_room()
    command_send_message(CMD_LEAVE_ROOM, {})
end

function desk_ready()
    command_send_message(CMD_ROOM_MESSAGE, "desk_op", {oper = "ready"})
end