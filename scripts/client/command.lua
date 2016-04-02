
function connect(account, password)
    LOGIN_D.login(account, password)
end

function c()
    connect("aa", "bb")
end

local function add_attrib(field, amount)
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(CMD_COMMON_OP, {oper = "add", field = field, amount = amount})
end

local function cost_attrib(field, amount)
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(CMD_COMMON_OP, {oper = "cost", field = field, amount = amount})
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
    local user = ME_D.get_user()
    if not is_object(user) then
        trace("请先登陆游戏")
        return
    end
    user:send_message(CMD_COMMON_OP, {oper = "add_item", class_id = class_id, amount = amount})
end