-- user.lua
-- Created by wugd
-- 玩家基类

ACCOUNT_CLASS = class(DBASE_CLASS, RID_CLASS, AGENT_CLASS, HEARTBEAT_CLASS, ATTRIB_CLASS);
ACCOUNT_CLASS.name = "ACCOUNT_CLASS";

function ACCOUNT_CLASS:create(value)
    assert(type(value) == "table", "account::create para not corret");
    self:replace_dbase(value);
    self:freeze_dbase()
    self:set("ob_type", OB_TYPE_ACCOUNT);

    REDIS_D.run_publish(REDIS_ACCOUNT_OBJECT_CONSTRUCT, self:query("rid"))
end

function ACCOUNT_CLASS:destruct()
    self:close_agent()

    REDIS_D.run_publish(REDIS_ACCOUNT_OBJECT_DESTRUCT, self:query("rid"))
end

-- 生成对象的唯一ID
function ACCOUNT_CLASS:get_ob_id()
    return (string.format("ACCOUNT_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("account"))));
end

function ACCOUNT_CLASS:accept_relay(agent)
    agent:relay_comm(self)
    self:set_authed(true)
end

function ACCOUNT_CLASS:set_login_user(user_ob, is_reconnect)
    local pre_ob = find_object_by_rid(self:query("user_rid"))
    if pre_ob and pre_ob:query("rid") ~= user_ob:query("rid") then
        pre_ob:set("account_rid", "")
        pre_ob:relay_comm(self)
        pre_ob:connection_lost(true)
    end
    user_ob:accept_relay(self, is_reconnect)
    user_ob:set("account_rid", self:get_rid())
    self:set("user_rid", user_ob:get_rid())
end

function ACCOUNT_CLASS:get_user_ob()
    return find_object_by_rid(self:query("user_rid"))
end

-- 连接断开时不立即析构对像，供断线重连
function ACCOUNT_CLASS:connection_lost()
    -- 如果存在user对象，则用户由user管理 
    local user_ob = find_object_by_rid(self:query("user_rid"))
    if is_object(user_ob) then
        user_ob:connection_lost(true)
    else
        destruct_object(self)
    end
end

-- 取得对象类
function ACCOUNT_CLASS:get_ob_class()
    return "ACCOUNT_CLASS";
end

function ACCOUNT_CLASS:is_account()
    return true
end
