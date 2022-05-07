-- user.lua
-- Created by wugd
-- 玩家基类

ACCOUNT_TDCLS = tdcls(DBASE_TDCLS, RID_TDCLS, AGENT_TDCLS, HEARTBEAT_TDCLS, ATTRIB_TDCLS);
ACCOUNT_TDCLS.name = "ACCOUNT_TDCLS";

function ACCOUNT_TDCLS:create(value)
    ASSERT(type(value) == "table", "account::create para not corret");
    self:replace_dbase(value);
    self:freeze_dbase()
    self:set("ob_type", OB_TYPE_ACCOUNT);

    REDIS_D.run_publish(REDIS_ACCOUNT_OBJECT_CONSTRUCT, self:query("rid"))
end

function ACCOUNT_TDCLS:destruct()
    self:close_agent()

    REDIS_D.run_publish(REDIS_ACCOUNT_OBJECT_DESTRUCT, self:query("rid"))
end

-- 生成对象的唯一ID
function ACCOUNT_TDCLS:get_ob_id()
    return (string.format("ACCOUNT_TDCLS:%s:%s", SAVE_STRING(self:query("rid")),
                         SAVE_STRING(self:query("account"))));
end

function ACCOUNT_TDCLS:accept_relay(agent)
    agent:relay_comm(self)
    self:set_authed(true)
end

function ACCOUNT_TDCLS:set_login_user(user_ob, is_reconnect)
    local pre_ob = find_object_by_rid(self:query("user_rid"))
    if pre_ob and pre_ob:query("rid") ~= user_ob:query("rid") then
        pre_ob:set("account_rid", "")
        pre_ob:relay_comm(self)
        pre_ob:connection_lost(true)
    end
    user_ob:accept_relay(self, is_reconnect)
    user_ob:set("account_rid", self:GET_RID())
    self:set("user_rid", user_ob:GET_RID())
end

function ACCOUNT_TDCLS:get_user_ob()
    return find_object_by_rid(self:query("user_rid"))
end

-- 连接断开时不立即析构对像，供断线重连
function ACCOUNT_TDCLS:connection_lost()
    -- 如果存在user对象，则用户由user管理 
    local user_ob = find_object_by_rid(self:query("user_rid"))
    if IS_OBJECT(user_ob) then
        user_ob:connection_lost(true)
    else
        DESTRUCT_OBJECT(self)
    end
end

-- 取得对象类
function ACCOUNT_TDCLS:get_ob_class()
    return "ACCOUNT_TDCLS";
end

function ACCOUNT_TDCLS:is_account()
    return true
end
