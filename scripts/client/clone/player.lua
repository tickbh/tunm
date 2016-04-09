-- player.lua
-- Created by wugd
-- 玩家基类

PLAYER_CLASS = class(DBASE_CLASS, RID_CLASS, AGENT_CLASS, HEARTBEAT_CLASS, ATTRIB_CLASS);
PLAYER_CLASS.name = "PLAYER_CLASS";

function PLAYER_CLASS:create(value)
    assert(type(value) == "table", "player::create para not corret");
    self:replace_dbase(value);
    self:set("ob_type", OB_TYPE_USER);
    self:freeze_dbase()
    self.carry = {}
end

function PLAYER_CLASS:destruct()
    for _,v in pairs(self.carry) do
        destruct_object(v)
    end
end

-- 生成对象的唯一ID
function PLAYER_CLASS:get_ob_id()
    return (string.format("PLAYER_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("account_rid"))));
end

-- 定义公共接口，按照字母顺序排序
-- 将连接对象转接到 player 对象上
function PLAYER_CLASS:accept_relay(agent)
    -- 将连接转换到 player 对象上
    agent:relay_comm(self)

    self:enter_world()
end

-- 玩家进入世界
function PLAYER_CLASS:enter_world()
    self:set_temp("entered_world", true)
    trace("玩家(%o/%s)进入游戏世界。", self:query("name"), get_ob_rid(self));
    trace("玩家等级: %d\r\n玩家金币: %d\r\n玩家钻石: %d", self:query("lv"), self:query("gold"), self:query("stone"))
end

-- 取得对象类
function PLAYER_CLASS:get_ob_class()
    return "PLAYER_CLASS";
end

function PLAYER_CLASS:is_user()
    return true;
end

function PLAYER_CLASS:load_property(object)
    self.carry[object:query("pos")] = object
end

function PLAYER_CLASS:unload_property(object)
    if not is_object(object) then
        return
    end
    local pos = object:query("pos")
    if pos then
        self.carry[pos] = nil
    end
    destruct_object(object)
end

function PLAYER_CLASS:get_page_carry(page)
    local arr = {};
    local x, y;
    local read_pos = READ_POS;
    for pos, ob in pairs(self.carry) do
        x, y = read_pos(pos);
        if x == page then
            arr[#arr + 1] = ob;
        end
    end
    return arr;
end