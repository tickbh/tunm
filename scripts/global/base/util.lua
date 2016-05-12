-- util.lua
-- Created by wugd
-- 工具函数

--红色
R = "\27[31m"

--绿色
G = "\27[32m"

--黄色
Y = "\27[33m"

--蓝色
B = "\27[34m"

--紫色
P = "\27[35m"

--白色
W = "\27[37m"

function table_maxn(value)
    local result = 0
    for k,_ in pairs(value) do
        if type(k) == "number" and k > result then
            result = k
        end
    end
    return result
end

if not table.maxn then
    table.maxn = table_maxn
end

function table_len(value)
    return #value
end

if not table.getn then
   table.getn = table_len
end

if not unpack then
    unpack = table.unpack
end

os_is_linux = true
if os.getenv( "windir" ) then
    os_is_linux = false
end

-- 打印信息
function trace(value,...)
    local a = {...}
    local i = 0
    if(type(value) == "string") then
        value = string.gsub(value,"%%([o,s,d])",function(c)
                                                    i = i+1
                                                    if c == "s" then
                                                        return a[i]
                                                    else
                                                        return (watch(a[i]))
                                                    end
                                                end)
    end

    lua_print(0, value)
end

-- 自定义调用栈输出
function traceback(log_to_file)
    local result = { "stack traceback:\n", }

    local i = 3
    local j = 1
    local file, line, func, var, value

    -- 遍历所有调用层次
    local source_info
    local debug_get_info = debug.getinfo
    local debug_get_local = debug.getlocal
    repeat
        source_info = debug_get_info(i,'Sln') -- .source
        if not source_info then
            do break end
        end

        -- 取得文件名、行号、函数名信息
        file = source_info.short_src or ""
        line = source_info.currentline or ""
        func = source_info.name or ""

        table.insert(result, string.format("\t(%d)%s:%s: in function '%s'\n",
                                           i - 2, file, line, func))
        if source_info.what ~= "C" and
           func ~= "_create" and func ~= "_destruct" and func ~= "new" then
            -- 遍历该层次的所有 local 变量
            j = 1
            repeat
                var, value = debug_get_local(i, j)
                if var and not string.find(var, "%b()") then
                    if value then
                        table.insert(result, string.format("\t\t%s : %s\n", tostring(var),
                                                           watch(value, "\t\t", 1)))
                    else
                        table.insert(result, string.format("\t\t%s : <nil>\n", tostring(var)))
                    end
                end

                j = j + 1
            until not var
        end

        i = i + 1
    until not source_info

    local str = table.concat(result, "")
    trace(str)
    return str
end

-- 重新定义assert函数，打印调用栈
function assert(e, msg)
    if not e then
        local err = string.format("Assert Failed: %s\n", tostring(msg))
        error(err)
        -- trace(err)
        -- traceback(true)
    end
end

-- 异常处理函数，打印调用栈
function error_handle(...)
    local err_msg = ...
    if is_table(err_msg) then
        err_msg = err_msg[1]
    end

    err_msg = string.format( "Error:\n%s\n", err_msg)
    trace( "%s", err_msg )
    traceback(true)
    return ""
end

__G__TRACKBACK__ = error_handle

function tdcall(f, ...)
    local args = {...}
    return xpcall(function() return f(unpack(args)) end, error_handle)
end

--合并一个table
function merge(src, t)
    if type(src) ~= "table" or type(t) ~= "table" then
        return src
    end
    for k, v in pairs(t) do
        src[k] = v
    end
    return src
end

function overload_same(src, t)
    if type(src) ~= "table" or type(t) ~= "table" then
        return src
    end
    for k,v in pairs(src) do
        if t[k] then
            src[k] = t[k]
        end
    end
    return src
end

-- 复制一个table
function dup(t)
    if (type(t) ~= "table") then
        return t
    end

    local new_t = {}
    for k, v in pairs(t) do
        new_t[k] = v
    end
    return new_t
end

--筛选两个数组中的不同元素
local function get_diffent_array(array, array_compare)
    local result, array2 = dup(array), dup(array_compare)
    for i,v in pairs(result) do
        for j, k in pairs(array2) do
            if v == k then
                result[i]= nil
            end
        end
    end
    return result
end

-- 将table用string表示，此结果可以用restore_value还原
-- 注意：本函数只处理一级，为防止死循环。此函数多用在通信中，多级的情况应很少见，如需多级，自行处理。
-- table_record 是用来记录内嵌的 table，防止死循环
function table_to_string(t, table_record)
    if (type(t) ~= "table") then
        return (tostring(t))
    end

    local s = "{"
    local tr = table_record

    -- 缓存该 table 已被处理
    if type(tr) == "table" then
        tr[t] = true
    else
        tr = {}
        tr[t] = true
    end

    for k, v in pairs(t) do
        local key, value
        if type(k) == "string" then
            key = k
        else
            key = "[" .. tostring(k) .. "]"
        end
        if type(v) == "string" then
            if (string.sub(v, 1, 1) == "{") and (string.sub(v, -1, -1) == "}") then
                value = v
            else
                value = "\"" .. v .. "\""
            end
        elseif type(v) == "table" and not tr[v] then
            value = table_to_string(v, tr)
        elseif type(v) == "table" then
            -- 存在嵌套 table
            assert(false, "table overflow!")
            return
        elseif type(is_buffer) == "function" and is_buffer(v) then
            -- 存在buffer
            value = (string.format("\"::%s::\"", buffer_to_string( v )))
        else
            value = tostring(v)
        end
        s = s .. key .. "=" .. value .. ","
    end
    s = s .. "}"
    return s
end

-- 将array类型的table用string表示，此结果可以用restore_value还原
function array_to_string(t)
    if (type(t) ~= "table") then
        return (tostring(t))
    end

    local s = "{"
    for i, v in ipairs(t) do
        local value
        if type(v) == "string" then
            if (string.sub(v, 1, 1) == "{") and (string.sub(v, -1, -1) == "}") then
                value = v
            else
                value = "\"" .. v .. "\""
            end
        else
            value = tostring(v)
        end
        s = s .. value .. ","
    end
    s = s .. "}"
    return s
end

function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return (string.format("'%s'", v))
    end
    return (string.format("\"%s\"", string.gsub(v,'"', '\\"' )))
  else
      if "table" == type( v ) then
          return (table.tostring( v ))
      elseif type(is_buffer) == "function" and is_buffer(v) then
          return (string.format("\"::%s::\"", buffer_to_string( v )))
      else
          return (tostring( v ))
      end
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return (string.format("[%s]", save_string( k )))
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, save_string( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        string.format("%s=%s", table.key_to_str( k ), save_string( v ) ))
    end
  end
  return (string.format("{%s}", table.concat( result, "," )))
end

function table_kv_to_array(t)
    local result = {}
    for k,v in pairs(t) do
        table.insert(result, k)
        table.insert(result, v)
    end
    return result
end

function table_key_to_array(t)
    local result = {}
    for k,v in pairs(t) do
        table.insert(result, k)
    end
    return result
end

function table_value_to_array(t)
    local result = {}
    for k,v in pairs(t) do
        table.insert(result, v)
    end
    return result
end

function table_get_key_value(t, keys)
    local result = {}
    for _,key in ipairs(keys) do
        result[key] = t[key]
    end
    return result
end

function array_to_table(t)
    local result = {}
    for _,key in ipairs(t) do
        result[key] = true
    end
    return result
end

function is_sub_array(array, sub_array)
    local src_table = array_to_table(array)
    for _,v in ipairs(sub_array) do
        if not src_table[v] then
            return false
        end
    end
    return true
end

--一旦发现未识别节点则返回失败
function sub_array(array, sub_array)
    local src_table = array_to_table(array)
    for _,v in ipairs(sub_array) do
        if not src_table[v] then
            return false
        end
        src_table[v] = nil
    end
    return true, table_key_to_array(src_table)
end

-- 保存成 string
function save_string(t)
    if (type(t) == "number") then
        return (tostring(t))
    elseif (type(t) == "string") then
        t = string.gsub(t, "[\r,\n,\\,\"]",
                      function(c)
                           if c == "\\" then
                               return "\\\\"
                           elseif c == "\r" then
                               return "\\r"
                           elseif c == "\n" then
                               return "\\n"
                           elseif c == "\"" then
                               return '\\"'
                           end
                      end
        )
        return (string.format("\"%s\"", t))
    elseif (type(t) == "table") then
        return (table.tostring(t))
    elseif type(is_buffer) == "function" and is_buffer(t) then
        return (string.format("\"::%s::\"", buffer_to_string( t )))
    else
        return (tostring(t))
    end
end

-- 将字符串表示的变量还原
function restore_value(s, ignore_buffer)
    assert(type(s) == "string", "restore_value arg error")

    if ignore_buffer then
        -- 替换buffer
        s = string.gsub(s, "\"::(%w+)::\"", replace_buffer)
    end

    local f, e = loadstring(string.format("return %s", s))
    if f then
        return (f())
    else
        assert(false, string.format("restore_value: %s \r\nExeption: %s", s, tostring(e)))
    end
end

-- 执行字符串命令
function do_command(s)
    assert(type(s) == "string", "do_command arg error: " .. s)

    -- 如果第一个字符为"'"
    if string.find(s, "'") == 1 then
        s = "watch(" .. string.sub(s, 2) .. ")"
    end

    local f, e = loadstring(string.format("%s", s))
    if f then
        return (f())
    else
        assert(false, "do_command: " .. s .. "\r\nExeption: " .. tostring(e))
    end
end

-- 查看变量
function watch(s, prefix, stack)
    local result = ""
    local sign = true

    prefix = prefix or ""
    stack = stack or 0
    if not prefix then
        prefix = ""
    end

    if s == nil then
        result = "<nil>"
    elseif (type(s) == "table") and type(s.is_clone) == "boolean" then
        -- 对象，不希望打印出所有的 table 信息
        local ob_id = s.get_ob_id and s:get_ob_id()
        if is_string(ob_id) then
            if s.destructed == true then
                result = string.format("object(%s<destructed>)", ob_id)
            else
                result = string.format("object(%s)", ob_id)
            end
        else
            result = string.format("object(%s)", save_string(s.class_type))
        end

    elseif (type(s) == "table") then
        local size = sizeof(s)
        --栈的深度设为3，避免循环
        if stack > 3 then
            return string.format("%s\tsize is %d,\r\n", prefix, size)
        end
        if string.len(prefix) > 20 then
            result = "<table overflow>"
        else
            local str_list = { string.format("<table>   size : %d\r\n%s{\r\n", size, prefix) }

            local times = 1
            for i, v in pairs(s) do
                sign = true
                if (type(i) == "string") and (type(v) == "table") then
                    -- 如果key值是以下划线开头，隐藏table的内容
                    -- 这个处理为避免上下级互相引用时出现死循环
                    local key = i

                    if (string.len(key) > 0) and (string.sub(key, 1, 1) == '_') then
                        table.insert(str_list, string.format("%s\t%s: <table hide>,\r\n",
                                     prefix, watch(i, prefix .. "\t", stack + 1)))
                        sign = false
                    end
                end

                if sign then
                    table.insert(str_list, string.format("%s\t%s:%s,\r\n", prefix,
                                 watch(i, prefix .. "\t", stack + 1), watch(v, prefix .. "\t", stack + 1)))
                end

                times = times + 1
                if times > 100 then
                    table.insert(str_list, "... ...")
                    break
                end

            end
            table.insert(str_list, string.format("%s}", prefix))
            result = table.concat(str_list, "")
        end
    elseif (type(s) == "function") then
        result = "<function>"
    elseif (type(s) == "string") then
        result = string.format("\"%s\"", string.gsub(s,'"', '\\"' ))
    elseif (type(s) == "number") then
        result = tostring(s)
    elseif (type(s) == "boolean") then
        result = (s and "true" or "false")
    else
        result = "unknow"
    end

    return result
end

if not std_print then
    std_print = print
end

function __FUNC__(level)
    local _level = 2
    if level ~= nil then
        _level = level + 2
    end

    local name = debug.getinfo(_level,'n').name
    if name == nil then
        name = ""
    end

    return name
end

function __LINE__(level)
    local _level = 2
    if level ~= nil then
        _level = level + 2
    end

    local currentline = debug.getinfo(_level, 'l').currentline
    if currentline == nil then
        currentline = ""
    end

    return currentline
end

function deep_dup(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" or is_object(object) then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return (setmetatable(new_table, getmetatable(object)))
    end
    return (_copy(object))
end

-- 创建对象
function clone_object(ob, ...)
    return (ob.new(...))
end

-- 析构对象
function destruct_object(ob)
    if ob and type(ob.destructing) ~= "boolean" and ob.destructed ~= true then
        ob.destructing = true
        if ob.destruct ~= nil_func then
            ob.destruct()
        elseif ob.destruct_object ~= nil_func then
            ob:destruct_object()
        end
        ob.destructed = true
    end
end

-- 查看脚本对象信息
function info_object(ob)
    if not is_table(ob) and type(ob) ~= "userdata" then
        return
    end

    local info = {}
    if type(ob.is_clone) == "boolean" then
        -- 对象，需要依次取出基类对象的接口

        -- 取得该对象对应的类模板
        local class_type = _G[ob.class_type]
        if not class_type then
            return
        end

        -- 取得该类模板的接口列表
        info = class_type:get_func_list()

        -- 取得该对象自身的接口
        for k, v in pairs(ob) do
            info[k] = v
        end
    elseif ob.get_func_list then
        info = ob:get_func_list()
    elseif type(ob) == "userdata" and tolua and tolua.type(ob) ~= "userdata" then
        -- c++ 对象，取得该对象接口
        local meta = getmetatable(ob)
        local first_char
        while meta do
            for key, value in pairs(meta) do
                first_char = string.sub(key, 1, 1)
                -- 下划线或点开头的不处理
                if first_char ~= '_' and first_char ~= '.' and not info[key] then
                    info[key] = value
                end
            end

            meta = getmetatable(meta)
        end
    else
        info = ob
    end

    -- 若有 is_clone 字段，则 watch 会显示一个 ob_id
    if info["is_clone"] then
        info["is_clone"] = nil
    end

    -- 遍历信息，对方法和变量进行排序分类
    local methods, variables = {}, {}
    for name, value in pairs(info) do
        if is_function(value) then
            methods[#methods + 1] = name
        else
            variables[#variables + 1] = name
        end
    end

    -- 排序
    table.sort(methods)
    table.sort(variables)

    return {
        methods = methods,
        variables = variables,
    }
end

-- 判断对象是否有效
function is_object(ob)
    if type(ob) == "table" and
       ob.destructed == false then
        return true
    else
        return false
    end
end

-- 判断是否为整数
function is_int(v)
    if type(v) == "number" then
        return true
    else
        return false
    end
end

-- 判断是否为字符串
function is_string(v)
    if type(v) == "string" then
        return true
    else
        return false
    end
end

-- 判断是否为 table
function is_table(v)
    if type(v) == "table" then
        return true
    else
        return false
    end
end

-- 判断是否为 array
function is_array(v)
    if type(v) ~= "table" then
        return false
    elseif table.getn(v) == 0 then
        return false
    else
        return true
    end
end

-- 判断是否为 mapping
-- mapping 不允许存在 int 型的 key，有 int 型的key 被认为是 array
function is_mapping(v)
    if type(v) ~= "table" then
        return false
    elseif table.getn(v) == 0 then
        return true
    else
        return false
    end
end

-- 判断是否为 function
function is_function(v)
    if type(v) == "function" then
        return true
    else
        return false
    end
end

-- 将变量转换成整数
function to_int(v)
    if is_int(v) then
        return v
    elseif not is_string(v) then
        return 0
    else
        return (tonumber(v))
    end
end

function sizeof(t)
    local n = 0
    if type(t) == "table" then
        -- 遍历 table，累加元素个数
        for __, __ in pairs(t) do
            n = n + 1
        end
    elseif type(t) == "string" then
        n = string.len(t)
    end

    return n
end

function is_empty_table(t)
    if type(t) ~= "table" then
        return false
    end

    for __, __ in pairs(t) do
        return false
    end

    return true
end

-- 整理数组
function clean_array(t)
    if not t then
        return
    end

    local n = 1
    local p, max
    local type = type
    local is_object = is_object

    local tmp = {}
    for _,v in pairs(t) do
        p = type(v)
        if p ~= "nil" and
           (p ~= "table" or not v.is_clone or is_object(v)) then
            -- 需要重新整理数组
            tmp[n] = v
            n = n + 1
        end
    end 
    t = tmp
    return t, n - 1
end

function trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- 将字符串根据标识符打断，组成 array
function explode(str, flag)
    local t, ll
    t = {}
    ll = 0

    if #str == 0 then
        return {}
    end

    if(#str == 1) then
        return { str }
    end

    local l
    while true do
        -- find the next d in the string
        l = string.find(str, flag, ll, true)

        -- if "not not" found then..
        if l ~= nil then
            -- Save it in our array.
            table.insert(t, string.sub(str, ll, l-1 ))

            -- save just after where we found it for searching next time.
            ll = l + 1
        else
            -- Save what's left in our array.
            table.insert(t, string.sub(str, ll))

             -- Break at end, as it should be, according to the lua manual.
             break
         end
    end

    return t
end


function explode_tonumber(str, flag)
    local t = explode(str, flag)
    local result = {}
    for _,v in ipairs(t) do
        result[#result + 1] = tonumber(v)
    end
    return result
end

--判断某个值是否在数组中
function is_in_array(value, array)

    if not is_array(array) then
        return
    end

    for _,v in pairs(array) do
        if v == value then
            return true
        end
    end

    return nil
end

function index_in_array(value, array)
    for id,v in ipairs(array) do
        if v == value then
            return id
        end
    end
    return nil
end

function restore_json(s)
    assert(type(s) == "string", "restore_json arg error")
    if sizeof(s) == 0 then
        return {}
    end
    local success, ret = pcall(json.decode, s)
    if success then
        return ret
    else
        assert(false, string.format("restore_json: %s \r\nExeption: %s", s, tostring(e)))
    end
end

function decode_json(s)
    assert(type(s) == "string", "decode_json arg error")
    if sizeof(s) == 0 then
        return {}
    end
    local success, ret = pcall(cjson.decode, s)
    if type(ret) ~= "table" then
        success = false
    end
    if success then
        return ret
    else
        return {}
    end
end

function encode_json(s)
    assert(type(s) == "table", "encode_json arg error")
    local success, ret = pcall(cjson.encode, s)
    if success then
        return ret
    else
        return "{}"
    end
end

function decode_json_check(s)
    assert(type(s) == "string", "decode_json_check arg error")
    if sizeof(s) == 0 then
        return {}
    end
    local success, ret = pcall(cjson.decode, s)
    if type(ret) ~= "table" then
        success = false
    end
    if success then
        return ret, success
    else
        return {}, success
    end
end

function encode_json_check(s)
    assert(type(s) == "table", "encode_json_check arg error")
    local success, ret = pcall(cjson.encode, s)
    if success then
        return ret, success
    else
        return "{}", success
    end
end


function get_rid(serverid)
    return get_next_rid(serverid or 1)
end

function get_first_key_value(t)
    if type(t) ~= "table" then
        return nil, nil
    end
    for key, value in pairs(t) do
        return key, value
    end
    return nil, nil
end

function call_func(f, tab, ...)
    local a, b, c, d, e = unpack(tab or {})
    if e ~= nil then
        return f(a, b, c, d, e, ...)
    elseif d ~= nil then
        return f(a, b, c, d, ...)
    elseif c ~= nil then
        return f(a, b, c, ...)
    elseif b ~= nil then
        return f(a, b, ...)
    elseif a ~= nil then
        return f(a, ...)
    else
        return f(...)
    end
end

function remove_get(t, key)
    local value = t[key]
    t[key] = nil
    return value
end

function array_sub(array, pos_start, pos_end)
    local result = {}
    for i = pos_start, pos_end do
        result[#result + 1] = array[i]
    end
    return result
end

-- 随机从数组array中取number个元素
function array_get_rand(array, number, filter_func, arg)
    -- 保存array数组下标
    local result = {}
    for i, data in pairs(array) do
        if filter_func then
            if filter_func(arg, i, data) then
                result[#result+1] = i
            end
        else
            result[#result+1] = i
        end
    end

    local array_size = #result
    local rand,temp
    if number < array_size then
        -- 前number个进行随机排序
        for i=1,number do
            rand = math.random(1,array_size)
            temp         = result[i]
            result[i]    = result[rand]
            result[rand] = temp
        end

    else
        number = array_size
    end

    -- result的前number个元素就是数组array随机取值的下标
    return array_sub(result, 1, number), number
end

--随机排列数组
function rand_sort_array(array)
    local size = #array
    local result = dup(array)
    local rand,temp
    for i = 1, size do
        rand = math.random(1, size)
        temp         = result[i]
        result[i]    = result[rand]
        result[rand] = temp
    end
    return result
end

-- 从文本文件中按行获取信息，读入一个array
function get_info_from_file(filename)
    local info_array = {}
    local file_str
    filename = get_full_path(filename)
    local fp = io.open(filename)
    if fp then
        io.input(filename)
        file_str   = io.read("*all")
        io.close(fp)
    else
        return {}
    end

    -- 兼容windows、unix格式
    file_str = string.gsub(file_str, "\r\n", "\n")
    info_array = explode(file_str, "\n")

    -- 去掉空白行
    for i, line in ipairs(info_array) do
        line = trim(line)
        if line == "" then
            info_array[i] = nil
        else
            info_array[i] = line
        end
    end
    clean_array(info_array)

    return info_array
end

function get_file_json(filename)
    local filename = get_full_path(filename)
    local fp = io.open(filename)
    local file_str
    if fp then
        io.input(filename)
        file_str   = io.read("*all")
        io.close(fp)
    end
    return decode_json(file_str)
end

function get_file_content(filename)
    local filename = get_full_path(filename)
    local fp = io.open(filename)
    local file_str
    if fp then
        io.input(filename)
        file_str   = io.read("*all")
        io.close(fp)
    end
    return file_str
end

function is_absolute_path(path)
    assert(type(path) == "string", "is_absolute_path arg error")
    if string.len(path) == 0 then
        return false
    end
    
    local s, e = string.find(path, "[a-zA-Z]:")
    if s == 1 then
        return true
    end
    
    s, e = string.find(path, "/")
    if s == 1 then
        return true
    end

    return false
end


function is_valid_timer(timer_id)
    return is_int(timer_id) and timer_id > 0
end

function append_to_array(src, data)
    if not src then
        return data
    end
    for _,v in ipairs(data) do
        table.insert(src, v)
    end
    return src
end

function set_table_read_only(t)
    local mt = {
        __newindex = function(t, k, v)
            error("attempt to update a read-only table!")
        end
    }
    setmetatable(t, mt) 
    return t
end


function check_sql_param_vailed(value)
    if not value then
        return true
    end
    if string.find(value, "[%s%+%*%`%/%$%#%~%!%@%#%%%&%[%]%=]") then
        return false
    end
    return true
end

function run_string(str)
    assert(type(str) == "string", "str must string")
    local f, e = loadstring(str)
    if f then
        return (f())
    else
        assert(false, string.format("run_string: %s \r\nExeption: %s", s, tostring(e)))
    end
end

function check_table_sql_vailed(t, fields)
    for _,field in ipairs(fields) do
        if not check_sql_param_vailed(t[field]) then
            return false, t[field]
        end
    end
    return true
end

assert(check_sql_param_vailed("1 or 1") == false)
assert(check_sql_param_vailed("1=1") == false)
assert(check_sql_param_vailed("1+1") == false)
assert(check_sql_param_vailed("1*1") == false)
assert(check_sql_param_vailed("1%1") == false)


function memory_use()
    return collectgarbage("count")
end

-- 取得类的所有克隆对象
function child_objects(c)
    clean_array(c.ob_list)
    return c.ob_list
end

function assert_eq(a, b, msg)
    if type(a) ~= type(b) then
        assert(false, msg)
    elseif type(a) == "table" then
        assert(sizeof(a) == sizeof(b), msg)
        for k,v in pairs(a) do
            assert(v == b[k], msg)
        end
    else
        assert(a == b, msg)
    end
end