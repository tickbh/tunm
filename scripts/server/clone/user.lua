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

    self:set_temp("container", clone_object(CONTAINER_CLASS, {rid = get_ob_rid(self)}))
end

function USER_CLASS:destruct()
    if self:query_temp("entered_world") then
        self:leave_world();

        -- 移除此 raiser
        remove_responder_from_raiser(self:get_ob_id());
        remove_audience_from_raiser(self:get_ob_id());

        -- 保存玩家相关数据
        USER_D.hiberate(self);
    end

    local account_ob = find_object_by_rid(self:query("account_rid"))
    if is_object(account_ob) then
        destruct_object(account_ob)
    end

    self:delete_logout_timer()
end

-- 生成对象的唯一ID
function USER_CLASS:get_ob_id()
    return (string.format("USER_CLASS:%s:%s", save_string(self:query("rid")),
                         save_string(self:query("account_rid"))));
end

function USER_CLASS:delete_logout_timer()
    if is_valid_timer(self.logout_timer) then
        delete_timer(self.logout_timer);
        self.logout_timer = nil;
    end
end

-- 定义公共接口，按照字母顺序排序
-- 将连接对象转接到 user 对象上
function USER_CLASS:accept_relay(agent, is_reconnect)
    
    -- 将连接转换到 user 对象上
    agent:relay_comm(self)
    
    if is_reconnect then
        self:send_message(MSG_RECONNECT_INFO, {ret = 0})
    end
    self:enter_world();
    self:delete_logout_timer()
end

function USER_CLASS:logout_callback()
    USER_D.user_logout(self);
end

-- 连接断开时不立即析构对像，供断线重连
function USER_CLASS:connection_lost(at_once)
    self:set("last_logout_time", os.time());
    if self:query_temp("login_act_time") ~= nil then
        self:add_attrib("all_login_time", os.time() - self:query_temp("login_act_time"))
    end

    if at_once then
        USER_D.user_logout(self);
    else
        self:close_agent()
        if not is_valid_timer(self.logout_timer) then
            self.logout_timer = set_timer(30, self.logout_callback, self);--30000
        end
    end
end

-- 玩家进入世界
function USER_CLASS:enter_world()
    --设置心跳时间
    self:set_heartbeat_interval(30000);
    -- 发送开始游戏的消息
    self:set_temp("entered_world", true)
    raise_issue(EVENT_USER_LOGIN, self)
    trace("玩家(%o  %s/%s)进入游戏世界。\n", self:query("name"), get_ob_rid(self), self:query("account_rid"));
   
    self:send_message(MSG_ENTER_GAME, self:query())

    self:set_temp("login_act_time", os.time())

    local value = {rid=get_ob_rid(self), online=1}
    USER_D.publish_user_attr_update(value)

    -- 日志记录玩家登录
    LOG_D.to_log(LOG_TYPE_LOGIN_RECORD, get_ob_rid(self), tostring(self:query("account_rid")), "", "");
end

-- 取得对象类
function USER_CLASS:get_ob_class()
    return "USER_CLASS";
end

-- 玩家离开世界
function USER_CLASS:leave_world()
    self:delete_hearbeat();
    raise_issue(EVENT_USER_LOGOUT, self)
    trace("玩家(%s/%s)离开游戏世界。\n", get_ob_rid(self), self:query("account_rid"));
    self:delete_temp("entered_world");

    local value = {rid=get_ob_rid(self), online=0}
    USER_D.publish_user_attr_update(value)

    LOG_D.to_log(LOG_TYPE_LOGOUT_RECORD, get_ob_rid(self), tostring(self:query("account_rid")), "", "");
end

-- 取得保存数据库的信息
function USER_CLASS:save_to_mapping()
      -- 玩家数据发生变化的字段
    local change_list = self:get_change_list()
    local data = {};

    for key,_ in pairs(change_list) do
        if USER_D.is_in_user_fields(key) then
            data[key] = self:query(key)
        end
    end
    return data
end

-- 取得数据库的保存路径
function USER_CLASS:get_save_path()
    return "user", { rid = get_ob_rid(self) };
end

function USER_CLASS:set_change_to_db(callback, arg)
    local dbase = self:save_to_mapping();
    if is_empty_table(dbase) then
        if callback then callback(arg, 0, {}) end
        return
    end
    local table_name, condition = self:get_save_path();
    local sql = SQL_D.update_sql(table_name, dbase, condition)
    DB_D.execute_db(table_name, sql, callback, arg)
    self:freeze_dbase()

    self:save_sub_content(callback, arg)
end

function USER_CLASS:save_sub_content(callback, arg)
    -- 取得玩家容器中的所有物件的保存信息
    for pos, ob in pairs(self:get_container():get_carry()) do
        assert(is_object(ob));
        if is_object(ob) then
            -- 取得该物件需要保存的 dbase
            local dbase, is_part = ob:save_to_mapping();
            if dbase then

                -- 取得该物件的保存操作相关信息
                local table_name, primary, oper = ob:get_save_oper();
                local sql;
                if oper == "insert" then
                    sql = SQL_D.insert_sql(table_name, dbase)
                elseif oper == "update" then
                    sql = SQL_D.update_sql(table_name, dbase, {rid = primary})
                else
                    assert(false, "unknow op")
                end

                DB_D.execute_db(table_name, sql, callback, callback_arg)
            end
        end
    end

end

-- 弹出提示文字
function USER_CLASS:notify_message_info(message, is_important)
    self:send_message(MSG_MESSAGE_TIP, {msg_type = MSG_TYPE_MESSAGE, msg_info = message})
end

-- 弹出提示框
function USER_CLASS:notify_dialog_ok(message, is_important)
    self:send_message(MSG_MESSAGE_TIP, {msg_type = MSG_TYPE_DIALOG, msg_info = message})
end

-- 弹出提示框
function USER_CLASS:notify_scroll(message, is_important)
    self:send_message(MSG_MESSAGE_TIP, {msg_type = MSG_TYPE_SCROLL, msg_info = message})
end

function USER_CLASS:is_user()
    return true;
end

-- 通知字段变更
function USER_CLASS:notify_fields_updated(field_names)
    self:notify_property_updated(get_ob_rid(self), field_names);
end

-- 通知物件加载
function USER_CLASS:notify_property_loaded(rid)
    local ob = find_object_by_rid(rid);
    local appearance = APPEARANCE_D.get_appearance(ob, "SELF");
    self:send_message(MSG_PROPERTY_LOADED, get_ob_rid(self), { appearance });
end

-- 通知物件删除
function USER_CLASS:notify_property_delete(rids)
    if is_string(rids) then
        rids = { rids };
    end
 
    self:send_message(MSG_PROPERTY_DELETE, rids );
end

-- 通知玩家物件字段变更
function USER_CLASS:notify_property_updated(rid, field_names)
    if is_string(field_names) then
        field_names = { field_names };
    end

    local ob = find_object_by_rid(rid);
    if not ob then
        return;
    end

    local info = APPEARANCE_D.build_object_info(ob, field_names);
    self:send_message(MSG_OBJECT_UPDATED, rid, info);
end

-- 保存所有记录
function USER_CLASS:save_all()
    USER_D.hiberate(self);
end

function USER_CLASS:get_attr_desc(fields)
    local result = {rid=get_ob_rid(self)}
    for _,v in ipairs(fields) do
        result[v] = self:query(v)
    end
    return result
end

function USER_CLASS:query_log_channel()
    return self:query_temp("LOG_CHANNEL")
end

function USER_CLASS:set_log_channel(channel)
    self:set_temp("LOG_CHANNEL", channel)
end

function USER_CLASS:get_container()
    return self:query_temp("container")
end
