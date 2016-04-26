--memoryd.lua
--create by wugd
--脚本内存监控机制
--table、metatable、funciton's upvalue

-- 声明模块名
MEMORY_D = {}
setmetatable(MEMORY_D, {__index = _G})
local _ENV = MEMORY_D
-- 协程
local mxc

-- 协程结束后的回调处理
local callback
local callback_arg

-- 协程挂起次数
local YIELD_TIME = 5000
local cur_times = 0

-- 定义内部接口，按照字母顺序排序


-- 检索父节点是否有自己
local function search_self(node, node_map)
    if node_map[node] then
        return true
    end
  --[[  if node_map["parent"] then
        if search_self(node, node_map["parent"]) then
            return true
        end
    end ]]
end

-- 检索产生泄漏的引用
local function search_leak(node, parent, obj, result, parent_path, search_record, check_weak)

    local current_path
    local mt, key_weak, value_weak
    local node_map = parent
    node_map[node] = true

    -- 取得该节点是否为弱表
    mt = debug.getmetatable(node)
    if mt then
        if mt["__mode"] then
            if string.find(mt["__mode"], "k") then
                key_weak = true
            end

            if string.find(mt["__mode"], "v") then
                value_weak = true
            end
        end
    end

    if not check_weak and key_weak and value_weak then
        -- 键值弱表不查找
        return
    end

    if cur_times >= YIELD_TIME then
        if type(mxc) == "thread" then
            cur_times = 0
            coroutine.yield()
        end
    else
       cur_times = cur_times + 1
    end

    for k, v in pairs(node) do

        if type(k) == "table" and (check_weak or not key_weak)then

            current_path =  parent_path .. "/" .. "key-is-table"

            if obj == k then
                result[#result + 1] = current_path
            else
                if not search_self(k, node_map) then
                    search_leak(k, node_map, obj, result, current_path, search_record, check_weak)
                end

                -- 获取对象的元表
                mt = debug.getmetatable(k)

                -- 判断是否需要查找弱表
                if mt then
                    if not search_self(mt, node_map) then
                        search_leak(mt, node_map, obj, result, current_path, search_record, check_weak)
                    end
                end
            end

        elseif is_string(k) or is_int(k) then
            current_path =  parent_path .. "/" .. k
        else
            current_path =  parent_path .. "/other type"
        end

        if type(v) == "table" and (check_weak or not value_weak)then

            if obj == v then
                result[#result + 1] = current_path
            else

                if not search_self(v, node_map) then
                    search_leak(v, node_map, obj, result, current_path, search_record, check_weak)
                end

                -- 获取对象的元表
                mt = debug.getmetatable(v)
                if mt then
                    if not search_self(mt, node_map) then
                        search_leak(mt, node_map, obj, result, current_path, search_record, check_weak)
                    end
                end
            end

        elseif type(v) == "function" then

            if not search_record[v] then
                search_record[v] = true
                -- 取得funciton's upvalue
                local fupv = get_func_upvalue(v)
                if fupv then
                    search_leak(fupv, node_map, obj, result, current_path, search_record, check_weak)
                end

                -- 取得funciton's env
                local fenv = debug.getfenv(v)
                if not search_self(fenv, node_map) then
                    search_leak(fenv, node_map, obj, result, current_path, search_record, check_weak)
                end

                -- 取得funciton's registry
                local freg = debug.getregistry(v)
                if not search_self(freg, node_map) then
                    search_leak(freg, node_map, obj, result, current_path, search_record, check_weak)
                end
                -- 获取对象的元表
                mt = debug.getmetatable(v)
                if mt then
                    if not search_self(mt, node_map) then
                        search_leak(mt, node_map, obj, result, current_path, search_record, check_weak)
                    end
                end
            end
        end
    end
end

-- 定义公共接口，按照字母顺序排序

-- 取得指定函数的upvalue
function get_func_upvalue(func)
    local tbl = {}
    local n = 1
    while true do
	local name, value = debug.getupvalue(func,n)
	if not name then
	    break
	end

	if value == nil then
	    value = {}
	end

	tbl[name] = value
	n= n + 1
    end
    return tbl
end

-- 检查单个对象当前被引用的地方
function check_leak_obj(obj, check_weak)
    local result = {}
    local search_record = {}
    local parent_path = "_G"

    -- 检索该对象泄漏的引用
    search_leak(_G, {}, obj, result, parent_path, search_record, check_weak)

    return result
end

-- 获取泄漏的对象列表
function get_leak_obj_list()

    -- 先手段执行lua回收处理
    collectgarbage("collect")

    -- 再获取已被析构对象列表
    -- 如果存在说明出现逻辑上泄漏
    return (get_all_destructed_obs())
end

-- 获得泄漏对象的引用
function check_leak_obj_refs(raiser, check_weak)
    -- 获得泄漏的对象表
    local leak_object_list = get_leak_obj_list()
    if sizeof(leak_object_list) == 0 then
        print("无内存泄漏\n")
        write_log("无内存泄漏\n")
        return
    end

    local result = {}
    local search_record = {}
    local parent_path = "_G"
    for _, obj in pairs(leak_object_list) do

        -- 检索该对象泄漏的引用
        search_leak(_G, {}, obj, result, parent_path, search_record, check_weak)
        if sizeof(result) > 0 then
            result["leak"] = watch(obj)

            if not raiser then
                -- 打印出泄漏信息
                print("%o", result)
            else
                -- 写日志
                local str_result = string.format("Error: %s\n", save_string(result))
                write_log(str_result)
            end
        end

        result = {}
        search_record= {}
    end
end

-- 创建内存检测协程
function get_leak_obj_refs(raiser, check_weak, f, f_arg)
    if not mxc then
        mxc = coroutine.create(function (val_a, val_b)
                                        check_leak_obj_refs(val_a, val_b) end)
        if type(mxc) == "thread" then

            callback = f
            callback_arg = f_arg

            -- 执行协程状态定时处理
            resume_timer(raiser, check_weak)
        end
    end
end

function resume_timer(a, b)
    if type(mxc) == "thread" then
        if coroutine.status(mxc) == "suspended" then
            coroutine.resume(mxc, a, b)
        elseif coroutine.status(mxc) == "dead" then
            mxc = nil
            cur_times = 0

            -- 执行回调
            if is_function(callback) and is_table(callback_arg) then
                callback(callback_arg[1], callback_arg[2])
            end
            return
        end
    end
    set_timer(5, resume_timer)
end

function create()
end

create()
