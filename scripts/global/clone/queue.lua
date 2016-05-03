-- equip.lua
-- Created by wugd
-- 装备对象类

-- 创建类模板
QUEUE_TDCLS = tdcls()
QUEUE_TDCLS.name = "QUEUE_TDCLS"

-- 构造函数
function QUEUE_TDCLS:create()
    self.first = 0
    self.last = -1
    self.data = {}
end


function QUEUE_TDCLS:push_front(value)
    local first = self.first - 1
    self.first = first
    self.data[first] = value
    return 1
end

function QUEUE_TDCLS:push_pack(queue, value)
    self.last = self.last + 1
    self.data[last] = value
    return self.last - self.first + 1
end

function QUEUE_TDCLS:pop_first()
    if self.first > self.last then
        return
    end
    local value = self.data[self.first]
    self.data[self.first] = nil
    self.first = first + 1
    return value
end

function QUEUE_TDCLS:pop_last()
    if self.first > self.last then
        return
    end
    local value = self.data[self.last]
    self.data[self.last] = nil
    self.last = self.last - 1
    return value
end

function QUEUE_TDCLS:get_size()
    if self.first > self.last then
        return 0
    end
    return self.last - self.first + 1
end

function QUEUE_TDCLS:get_first(queue)
    return self.data[self.first]
end

function QUEUE_TDCLS:get_data()
    return self.data
end