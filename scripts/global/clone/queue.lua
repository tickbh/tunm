-- equip.lua
-- Created by wugd
-- 装备对象类

-- 创建类模板
QUEUE_CLASS = class()
QUEUE_CLASS.name = "QUEUE_CLASS"

-- 构造函数
function QUEUE_CLASS:create()
    self.first = 0
    self.last = -1
    self.data = {}
end


function QUEUE_CLASS:push_front(value)
    local first = self.first - 1
    self.first = first
    self.data[first] = value
    return 1
end

function QUEUE_CLASS:push_pack(queue, value)
    self.last = self.last + 1
    self.data[last] = value
    return self.last - self.first + 1
end

function QUEUE_CLASS:pop_first()
    if self.first > self.last then
        return
    end
    local value = self.data[self.first]
    self.data[self.first] = nil
    self.first = first + 1
    return value
end

function QUEUE_CLASS:pop_last()
    if self.first > self.last then
        return
    end
    local value = self.data[self.last]
    self.data[self.last] = nil
    self.last = self.last - 1
    return value
end

function QUEUE_CLASS:get_size()
    if self.first > self.last then
        return 0
    end
    return self.last - self.first + 1
end

function QUEUE_CLASS:get_first(queue)
    return self.data[self.first]
end

function QUEUE_CLASS:get_data()
    return self.data
end