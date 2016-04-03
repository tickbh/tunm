-- user.lua
-- Created by wugd
-- 玩家基类

USER_CLASS = class(DBASE_CLASS, RID_CLASS, AGENT_CLASS, HEARTBEAT_CLASS, ATTRIB_CLASS);
USER_CLASS.name = "USER_CLASS";

function USER_CLASS:create(value)
    assert(type(value) == "table", "user::create para not corret");
    self:replace_dbase(value);
    self:set("ob_type", OB_TYPE_USER);
    self:freeze_dbase()

end

function USER_CLASS:destruct()

end

-- 生成对象的唯一ID
function USER_CLASS:get_ob_id()
    return (string.format("USER_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("account_rid"))));
end

-- 定义公共接口，按照字母顺序排序
-- 将连接对象转接到 user 对象上
function USER_CLASS:accept_relay(agent)
    -- 将连接转换到 user 对象上
    agent:relay_comm(self)

    self:enter_world()
end

-- 玩家进入世界
function USER_CLASS:enter_world()
    self:set_temp("entered_world", true)
    trace("玩家(%o/%s)进入游戏世界。", self:query("name"), get_ob_rid(self));
    trace("玩家等级: %d\r\n玩家金币: %d\r\n玩家钻石: %d", self:query("lv"), self:query("gold"), self:query("stone"))
end

-- 取得对象类
function USER_CLASS:get_ob_class()
    return "USER_CLASS";
end

function USER_CLASS:is_user()
    return true;
end
