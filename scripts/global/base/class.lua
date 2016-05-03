-- tdcls.lua
-- Created by wugd
-- Lua实现多重继承的一种方案

local _class={}

local all_cloned_obs = {}
setmetatable(all_cloned_obs, { __mode = "kv" })

-- 取得所有克隆的对象
function get_all_cloned_obs()
    return all_cloned_obs
end

-- 取得所有已析构的对象
function get_all_destructed_obs()
    local list = {}
    for _, ob in pairs(all_cloned_obs) do
        if is_table(ob) and ob.destructed == true then
            table.insert(list, ob)
        end
    end

    return list
end

-- 取得指定类的指定函数
function get_class_func(c, func_name)
    if not _class[c] then
        return;
    end

    return _class[c][func_name]
end
function nil_func()
    return nil
end

-- 在 table plist 中查找 k
local function search(k, plist)
    for i = 1, #plist do
        -- 尝试第 i 个基类
        local v = _class[plist[i]][k]

        -- 若基类中存在相关的值，则返回父类的值
        if v ~= nil_func then
            return v
        end
    end

    return
end

function tdcls(...)
    local class_type={}
    class_type.create=false
    class_type.destruct=false
    class_type.name = ""
    class_type.super={...}
    class_type.ob_list = {}
    setmetatable(class_type.ob_list, { __mode = "v" })

    -- 类对象创建函数
    class_type.new=function(...)
        --trace("____class_type.new=function(...)_____")
        local obj={ is_clone = true, destructed = false }

        -- 这一句被我提前了，解决构造函数里不能调成员函数的问题
        -- 设置新对象的元表，其中的 index 元方法设置为一个父类方法查找表
        setmetatable(obj,{ __index= _class[class_type] })

        do
            local _create

            -- 创建对象时，依次调用父类的 create 函数
            _create = function(c,...)
                if table.getn(c.super) > 0 then
                    for i, v in ipairs(c.super) do
                        _create(v,...)
                    end
                end
                if c.create then
                    c.create(obj,...)
                end
            end

            _create(class_type,...)
        end

        -- 记录创建的类对象
        class_type.ob_list[#class_type.ob_list + 1] = obj

        -- 将对象加入弱表中，用于内存泄漏的检测
        all_cloned_obs[#all_cloned_obs + 1] = obj
        return obj
    end

    -- 取得类对象接口函数
    class_type.get_func_list=function(c)
        local func_list = {}
        local _find

        _find = function(c, func_list)
            if table.getn(c.super) > 0 then
                for i, v in pairs(c.super) do
                    _find(v, func_list)
                end
            end

            if _class[c] then
                for k, v in pairs(_class[c]) do
                    if v ~= nil_func then
                        func_list[k] = v
                    end
                end
            end

            func_list["is_clone"] = nil
        end

        _find(c, func_list)

        return func_list
    end

    -- 创建一个父类方法的查找表
    local vtbl = { }
    _class[class_type]=vtbl

    -- 设置该类的 newindex 元方法
    setmetatable(class_type,{__newindex=
        function(t,k,v)
            vtbl[k]=v
        end
    })

    -- 类对象析构函数
    vtbl.destruct_object=function(obj)
        do
            local _destruct

            -- 析构对象时，依次调用父类的 destruct 函数
            _destruct = function(c)
                if c.destruct then
                    local status, e = pcall(c.destruct, obj)
                    if not status then
                        error_handle(tostring(e))
                        --[[trace("Error:")
                        trace(tostring(e))
                        traceback()    ]]
                    end
                end

                if table.getn(c.super) > 0 then
                    for i = #c.super, 1, -1 do
                        _destruct(c.super[i])
                    end
                end
            end

            _destruct(class_type)
        end
    end

    -- 调用基类函数
    vtbl.base=function(obj, c, f, ...)
        -- 取得基类名+函数名的 key
        local k = string.format("%s%s", c.name, f)
        local ret = vtbl[k]

        if ret ~= nil_func then
            -- 已存在该基类函数，直接调用
            local a, b, c, d, e = ret(obj, ...)
            return a, b, c, d, e
        end

        -- 遍历基类，查找函数
        if table.getn(c.super) > 0 then
            for i = #c.super, 1, -1 do
                ret = search(f, c.super)
                if ret then
                    -- 取得基类函数，则调用之
                    vtbl[k] = ret
                    local a, b, c, d, e = ret(obj, ...)
                    return a, b, c, d, e
                end
            end
        end

        -- vtbl[k] = nil_func
    end

    -- 若该类有继承父类，则为父类查找表 vtbl 设置 index 元方法（查找父类的可用方法）
    if table.getn(class_type.super) > 0 then
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret
                if k == "class_type" then
                    ret = class_type.name
                else
                    ret = search(k, class_type.super)
                end

                if not ret then
                    ret = nil_func
                end

                vtbl[k]=ret
                return ret
            end
        })
    else
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret = nil_func
                if k == "class_type" then
                    ret = class_type.name
                end

                vtbl[k]=ret
                return ret
            end
        })
    end

    return class_type
end

--[[

现在，我们来看看怎么使用：

base_type=tdcls()               -- 定义一个基类 base_type

function base_type:create(x)      -- 定义 base_type 的构造函数
        trace("base_type create")
        self.x=x
end

function base_type:print_x()    -- 定义一个成员函数 base_type:print_x
        trace(self.x)
end

function base_type:hello()      -- 定义另一个成员函数 base_type:hello
        trace("hello base_type")
end

以上是基本的 tdcls 定义的语法，完全兼容 lua 的编程习惯。我增加了一个叫做 ctor 的词，作为构造函数的名字。
下面看看怎样继承：

test=tdcls(base_type)   -- 定义一个类 test 继承于 base_type

function test:create()    -- 定义 test 的构造函数
        trace("test create")
end

function test:hello()   -- 重载 base_type:hello 为 test:hello
        trace("hello test")
end

现在可以试一下了：

a=test.new(1)   -- 输出两行，base_type create 和 test create 。这个对象被正确的构造了。
a:print_x()     -- 输出 1 ，这个是基类 base_type 中的成员函数。
a:hello()       -- 输出 hello test ，这个函数被重载了。

--]]
