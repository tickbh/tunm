-- heartbeat.lua
-- Created by wugd
-- 心跳基类

-- 创建类模板
HEARTBEAT_TDCLS = tdcls();
HEARTBEAT_TDCLS.name = "HEARTBEAT_TDCLS";

-- 构造函数
function HEARTBEAT_TDCLS:create(para)
    self.heartbeat_timer = -1;
    self.interval        = 0.0;
    self.is_destructed   = false;
end

-- 析构函数
function HEARTBEAT_TDCLS:destruct()
    if is_valid_timer(self.heartbeat_timer) then
        delete_timer(self.heartbeat_timer);
        self.heartbeat_timer = -1;
    end
    self.is_destructed = true;
end

-- 心跳函数
function HEARTBEAT_TDCLS:do_heartbeat()
    if self.is_destructed then
        delete_timer(self.heartbeat_timer);
        self.heartbeat_timer = -1;
    end

    -- 执行心跳回调函数
    xpcall(post_heartbeat, error_handle, self:get_ob_class(), self);
end

-- 定义公共接口，按照字母顺序排序

-- 设置心跳时间
function HEARTBEAT_TDCLS:delete_hearbeat()
    if is_valid_timer(self.heartbeat_timer) then
        delete_timer(self.heartbeat_timer);
        self.heartbeat_timer = -1;
    end
end

-- 设置心跳时间
function HEARTBEAT_TDCLS:set_heartbeat_interval(_interval)
    self:delete_hearbeat()
    assert(_interval >= 10000);

    -- 开始心跳
    self.interval = _interval;
    self.heartbeat_timer = set_timer(_interval, self.do_heartbeat, self, true);
end
