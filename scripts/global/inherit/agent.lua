-- agent.lua
-- Created by wugd
-- 连接对象基类

-- fport_no 为转发的端口号，用于网关服，逻辑服
-- port_no 为真实的端口号

-- 创建类模板
AGENT_TDCLS = tdcls();
AGENT_TDCLS.name = "AGENT_TDCLS";

-- 构造函数
function AGENT_TDCLS:create()
    self.port_no  = -1;
    self.fport_no = -1;
    self.timer_id = -1;
    self.client_ip = -1;
    self.forward_unique = -1;
    self.server_type = 0;
    self.client_seq = -1;
    self.server_seq = 234;

    self.code_type = 0;
    self.code_id = 0;

    self.sended_close = false

    self.websocket = false;
    self.authed = false;
    -- 保存agent数据
    self.data = {};
end

function AGENT_TDCLS:set_sended_close(close)
    self.sended_close = close
end

function AGENT_TDCLS:get_sended_close()
    return self.sended_close
end

function AGENT_TDCLS:calc_next_seq(seq)
    seq = seq + 111;
    seq = bit32.band(seq, 0xFFFF);
    return seq;
end

function AGENT_TDCLS:get_next_server_seq()
    self.server_seq = self:calc_next_seq(self.server_seq)
    TRACE("get_next_server_seq == %o", self.server_seq)
    return self.server_seq
end

function AGENT_TDCLS:check_next_client(seq)
    if self.client_seq < 0 then
        self.client_seq = seq
    else
        self.client_seq = self:calc_next_seq(self.client_seq)
    end
    return self.client_seq == seq
end

function AGENT_TDCLS:set_client_seq(seq)
    self.client_seq = seq
end

function AGENT_TDCLS:close_agent()
    if self.fport_no ~= -1 then
        remove_port_agent(self.fport_no, self.sended_close);
    elseif self.port_no ~= -1 then
        remove_port_agent(self.port_no, self.sended_close);
        close_fd(self.port_no)
    end
    self.fport_no = -1
    self.port_no = -1
end

-- 析造函数
function AGENT_TDCLS:destruct()
    self:close_agent()
    if IS_VALID_TIMER(self.timer_id) then
        delete_timer(self.timer_id);
        self.timer_id = -1;
    end
end

-- 生成对象的唯一ID
function AGENT_TDCLS:get_ob_id()
    return (string.format("AGENT_TDCLS:%s:%s", SAVE_STRING(self.fport_no), SAVE_STRING(self.port_no)));
end

-- 定义公共接口，按照字母顺序排序

-- 连接断开
function AGENT_TDCLS:connection_lost()
    DESTRUCT_OBJECT(self)
end

-- 获取数据
function AGENT_TDCLS:get_data(key)
    return self.data[key];
end

-- 保存数据
function AGENT_TDCLS:set_data(key, value)
    self.data[key] = value;
end

function AGENT_TDCLS:get_fport_no()
    return self.fport_no
end

-- 取得连接号
function AGENT_TDCLS:get_port_no()
    return self.port_no;
end

function AGENT_TDCLS:get_uni_port_no()
    if self.fport_no == -1 then
        return self.port_no
    else
        return self.fport_no
    end
end

-- 取得该 agent 是否通过验证
function AGENT_TDCLS:is_authed()
    return self.authed;
end

-- 转接通讯端口到另一个对象上
function AGENT_TDCLS:relay_comm(to_comm)
    -- 取消本对象的端口-对象的映射
    if self.port_no == -1 then
        return;
    end
    
    to_comm:close_agent()
    -- 绑定到另一个连接 ob 上
    to_comm:set_authed(true)
    to_comm:set_all_port_no(self.fport_no, self.port_no)
    to_comm:set_client_ip(self:get_client_ip())

    -- 清除本对象信息
    self.port_no = -1
    self.fport_no = -1
end

function AGENT_TDCLS:forward_client_message(msg)
    local port_no = self.port_no;
    if port_no == -1 then
        return;
    end

    pcall(forward_to_port, port_no, msg)
end

function AGENT_TDCLS:send_net_msg(net_msg)
    TRACE("AGENT_TDCLS:send_net_msg %o", self.fport_no)
    if self.fport_no ~= -1 then
        net_msg:set_real_fd(self.fport_no)
        net_msg:end_msg()
    else
        net_msg:end_msg()
    end


    -- 缓存中没消息，直接发送该消息
    local _, ret = pcall(send_msg_to_port, self.port_no, net_msg);
    return ret
end

-- 发送消息
function AGENT_TDCLS:send_dest_message(data, msg, ...)
    local port_no = self.port_no;
    if port_no == -1 then
        return;
    end
    TRACE("send_message msg = %o args = %o", msg, {...})
    local net_msg = pack_message(self:get_msg_type(), msg, ...)
    net_msg:set_to_svr_type(data["code_type"] or self.code_type)
    net_msg:set_to_svr_id(data["code_id"] or self.code_id)
    net_msg:set_msg_flag(data["msg_flag"] or 0)
    local ret = self:send_net_msg(net_msg)
    TRACE("????????????????? = %o", msg, ret)

    if ret == 0 then
        -- 发送成功
        local flag = get_send_debug_flag();
        if (type(flag) == "number" and flag == 1) or
           (type(flag) == "table" and self:is_user() and flag[self:GET_RID()]) then
            TRACE("################### cmd : %s ###################\n%o",
                  msg, { ... });
        end
    elseif self:is_user() then
        -- 表示发送缓存区已满，若是玩家直接关闭该连接
        if ret == 2 then
            TRACE("玩家 socket 发送缓存区已满，断开该连接。");
            set_timer(10, self.connection_lost, self);
            WRITE_LOG(string.format("Error: socket 发送缓存区已满，断开该连接。玩家(%s),send_message(%s)\n",
                                     self:query("rid"), tostring(msg) ));
        end
    end

    del_message(net_msg)
    return;
end

-- 发送消息
function AGENT_TDCLS:send_gate_message(msg, ...)
    return self:send_dest_message({code_type=SERVER_TYPE_GATE}, msg, ...)
end

-- 发送消息
function AGENT_TDCLS:send_client_message(msg, ...)
    return self:send_dest_message({code_type=SERVER_TYPE_CLIENT}, msg, ...)
end

-- 发送消息
function AGENT_TDCLS:send_message(msg, ...)
    return self:send_dest_message({code_type=self.code_type, code_id=self.code_id}, msg, ...)
end

-- 发送打包好的消息
function AGENT_TDCLS:send_raw_message(msg_buf)
    local port_no = self.port_no;
    if port_no == -1 then
        return;
    end

    local name, net_msg = pack_raw_message(msg_buf)
    TRACE("ooooooooooooooooo %o", name)
    local ret = self:send_net_msg(net_msg)
    if ret == 0 then
        -- 发送成功
        local flag = get_send_debug_flag();
        if (type(flag) == "number" and flag == 1) or
           (type(flag) == "table" and self:is_user() and flag[self:GET_RID()]) then
            TRACE("################### msg : %d ###################", net_msg:getPackId());
        end
    elseif ret == 2 then
        -- 表示发送缓存区已满，若不是玩家，则需要缓存，若是玩家直接关闭该连接
        if self:is_user() then
            TRACE("玩家 socket 发送缓存区已满，断开该连接。");
            set_timer(10, self.connection_lost, self);
            WRITE_LOG(string.format("Error: 玩家(%s) send_raw_message 发送缓存区已满，断开该连接。", self:query("rid")));
        end
    end
    del_message(net_msg)
end

-- 设置该 agent 是否通过验证
function AGENT_TDCLS:set_authed(flag)
    self.authed = flag;
    if flag then
        -- 该 agent 通过验证，则需要删除析构的定时器
        if IS_INT(self.timer_id) and self.timer_id > 0 then
            delete_timer(self.timer_id);
            self.timer_id = -1;
        end
    end
end

-- 析构agent并写日志
function AGENT_TDCLS:destruct_not_verify()
    DESTRUCT_OBJECT(self);
end

function AGENT_TDCLS:set_all_port_no(fport_no, port_no)
    self:set_fport_no(fport_no)
    self:set_port_no(port_no)
end

-- 设置连接号与 agent 的绑定关系
function AGENT_TDCLS:set_port_no(port_no)
    if self.fport_no ~= -1 then
        self.port_no = port_no
    else
        -- 之前已存在旧连接，需要关闭旧连接
        if self.port_no ~= -1 then
            -- 取消本对象的端口-对象的映射
            remove_port_agent(self.port_no);

            -- 关闭该连接
            TRACE("set_port_no agent repeat close_port %d and new port_no is %d", self.port_no, port_no);
            close_fd(self.port_no);
        end

        -- 设置新的连接号
        self.port_no = port_no;

        -- 设置 port_no 与 agent 绑定关系
        if port_no ~= -1 then
            set_port_agent(port_no, self);
        end

        if type(self.authed) ~= "boolean" or not self.authed then
            -- 该 agent 未验证，则设置超时析构
            self.timer_id = set_timer(60000, self.destruct_not_verify, self);
        end
    end

end

-- 判断agent是否有效
function AGENT_TDCLS:is_valid()
    if self.port_no == -1 then
        return false;
    end

    return true;
end

function AGENT_TDCLS:set_client_ip(client_ip)
    self.client_ip = client_ip
end

function AGENT_TDCLS:get_client_ip()
    return self.client_ip
end

function AGENT_TDCLS:set_server_type(type)
    self.server_type = type
    set_type_port(self.server_type, self.fport_no == -1 and self.port_no or self.fport_no)
end

function AGENT_TDCLS:set_code_type(code_type, code_id)
    self.code_type = code_type
    self.code_id = code_id
    set_code_type_port(self.code_type, self.code_id, self.fport_no == -1 and self.port_no or self.fport_no)
end

function AGENT_TDCLS:get_code_type()
    return self.code_type, self.code_id
end


function AGENT_TDCLS:get_server_type()
    return self.server_type
end

function AGENT_TDCLS:is_user()
    return false
end

-- 设置连接号与 agent 的绑定关系
function AGENT_TDCLS:set_fport_no(port_no)
    -- 之前已存在旧连接，需要关闭旧连接
    if self.fport_no ~= -1 then
        -- 取消本对象的端口-对象的映射
        remove_port_agent(self.fport_no);
    end

    -- 设置新的连接号
    self.fport_no = port_no;

    -- 设置 port_no 与 agent 绑定关系
    if port_no ~= -1 then
        set_port_agent(port_no, self);
    end

end

-- 给逻辑服发送消息，网关服调用
function AGENT_TDCLS:send_logic_message(msg, ...)
    local logic_port = get_map_port(self.port_no)
    if logic_port == -1 then
        TRACE("no logic server for %o", self.port_no)
        return
    end
    local net_msg = pack_message(self:get_msg_type(), msg, ...)
    net_msg:set_seq_fd(self.port_no)
    pcall(send_msg_to_port, logic_port, net_msg);
    del_message(net_msg)
end

function AGENT_TDCLS:forward_logic_message(net_msg)
    local logic_port = get_map_port(self.port_no)
    if logic_port == -1 then
        TRACE("no logic server for %o", self.port_no)
        return
    end
    net_msg:set_seq_fd(self.port_no)
    pcall(forward_to_port, logic_port, net_msg);
end

function AGENT_TDCLS:forward_server_message(net_msg, client_port)
    net_msg:set_msg_flag(MSG_FLAG_FORWARD)
    net_msg:set_from_svr_type(tonmumber(CODE_TYPE))
    net_msg:set_from_svr_id(tonmumber(CODE_ID))
    net_msg:set_real_fd(client_port)
    net_msg:end_msg()
    -- 缓存中没消息，直接发送该消息
    local _, ret = pcall(send_msg_to_port, self.port_no, net_msg);
    return ret
end

function AGENT_TDCLS:print_fd_info()
    TRACE("____AGENT_TDCLS:print_fd_info()____\n self is %o, fport_no is %o, and bit fport is %o port_no is %o", self, self.fport_no, bit32.band(self.fport_no, 0xFFFF), self.port_no)
end

function AGENT_TDCLS:get_msg_type()
    -- if self.websocket then
    --     return MSG_TYPE_JSON
    -- end
    return MSG_TYPE_TD
end

function AGENT_TDCLS:set_websocket(websocket)
    self.websocket = websocket
end

function AGENT_TDCLS:is_websocket()
    return self.websocket
end

function AGENT_TDCLS:set_forward_unique(unique)
    self.forward_unique = unique
end

function AGENT_TDCLS:get_forward_unique()
    return self.forward_unique
end
