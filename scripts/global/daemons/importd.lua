-- importd.lua
-- 读取csv文件，并转成相应的格式
-- 声明模块名
IMPORT_D = {}
setmetatable(IMPORT_D, {__index = _G})
local _ENV = IMPORT_D

local splitChar = "\t"

-- 定义内部接口，按照字母顺序排序

--读取csv文件，存入数组，以#开头的为注释
--正文第一行为字段的类型，第二行为字段名
local function handle_line(line)

    local row = {}

    --如果为#开头，不做任何处理
    line = trim(line)
    if string.find(line,"^#")  or string.find(line,"^\"#")then

    --如果开头为&则，则读取转换表
    --[[  elseif string.find(line,"^&#") or string.find(line,"^\"&#") then
        --去除头尾的"&#"
        line = trim(string.gsub(line,"^(\"?)&#",""))
        line = trim(string.gsub(line,"(\"?)$",""))
        csv["transformation"] = restore_value(line)]]--
    else
        line = line .. splitChar
        local linestart = 1

        repeat
            --字段中以"开头，则该字段可能含有""
            if (string.find(line,"^\"",linestart)) then
            local a,c
            local i = linestart

            --找不到""而只有"即该字段结束
            repeat
                a,i,c = string.find(line,'"("?)',i+1)
            until c ~= "\""

            if not i then
                assert(nil)
                error("unmatched")
            end

            local s     = string.sub(line,linestart+1,i-1)
            row[#row+1] = trim(string.gsub(s,"\"\"","\""))
            linestart   = string.find(line,splitChar,i) + 1

            else
                local nexti = string.find(line, splitChar, linestart)
                row[#row+1] = trim(string.sub(line,linestart,nexti-1))
                linestart   = nexti + 1
            end
        until linestart > string.len(line)
    end

    return row
end

--读取csv文件，存入数组，以#开头的为注释
--正文第一行为字段的类型，第二行为字段名
local function readcsv (file)
    local csv = {}
    local row = {}
    local failed = false

    local fp = io.open(get_full_path(file))

    if fp then
        for line in fp:lines() do

            if (string.find(line,"^#test_section") or string.find(line,"^\"#test_section")) then
                break
            end
            row = handle_line(line)
            --判断该行是否空行,若为空则不加入
            for _,v in ipairs(row) do
                if v ~= "" then
                    csv[#csv + 1] = row
                    break
                end
            end
        end

        io.close(fp)
    end

    if failed then
        print(R.."加载文件(%o)时找不到该文件。\n"..W, file)
    end
    return csv
end

-- 定义公共接口，按照字母顺序排序

--将array转成mapping,默认array第一行为字段类型,
--第二行为字段名。
function array_to_mapping(array)
    if #array < 2 then
        return
    end

    local mapping = {}

    --检查关键字是否有重复
    if checkkeys(array) then
        local fieldtype = array[1]
        local fieldname = array[2]
        for i =  3,#array do
            row = {}

            for j = 1,#fieldname do
                --如果字段类型为string则不需还原
                if fieldtype[j] == "string" then
                    row[fieldname[j]] = array[i][j]
                elseif fieldtype[j] == "int" and sizeof(array[i][j]) == 0 then
                    row[fieldname[j]] = 0
                elseif fieldtype[j] == "table" then
                    row[fieldname[j]] = restore_json(array[i][j])
                elseif fieldtype[j] == "float" and sizeof(array[i][j]) == 0 then
                    row[fieldname[j]] = 0
                else
                    row[fieldname[j]] = restore_value(array[i][j])
                end
            end

            if fieldtype[1] == "string" then
                mapping[array[i][1]] = row
            elseif fieldtype[1] == "int" and sizeof(array[i][1]) == 0 then
                mapping[0] = row
            elseif fieldtype[1] == "float" and sizeof(array[i][1]) == 0 then
                mapping[0] = row
            elseif fieldtype[1] == "table" and sizeof(array[i][1]) == 0 then
                row[{}] = row
            else
                local index = restore_value(array[i][1])
                if not index then
                    print(R.."%o未定义! 配置表结构如下:\n%o\n"..W, array[i][1], fieldname)
                end
                mapping[index] = set_table_read_only(row)
            end
        end
    end

    return mapping
end

--将数组转成具有映射关系的table,默认array第一行为字段类型,
--第二行为字段名。
function array_to_tables(array)
    if #array < 2 then
        return
    end

    local fieldtype = array[1]
    local fieldname = array[2]
    local tables = {}

    for i = 3,#array do
        local row = {}

        for j = 1,#fieldname do

            --如果字段类型为string则不需还原
            if fieldtype[j] == "string" then
                row[fieldname[j]] = array[i][j]
            elseif fieldtype[j] == "int" and sizeof(array[i][j]) == 0 then
                row[fieldname[j]] = 0
            elseif fieldtype[j] == "table" then
                row[fieldname[j]] = restore_json(array[i][j])
           elseif fieldtype[j] == "float" and sizeof(array[i][j]) == 0  then
                row[fieldname[j]] = 0
            else
                row[fieldname[j]] = restore_value(array[i][j])
            end
        end

        tables[#tables + 1] = row
    end

    return tables
end

-- 构造csv表其中两列的映射关系
function build_mapping(table, field_key, field_value)
    local result = {}
    -- readcsv_to_tables产生的类型
    if is_array(table) then
        for _, value in ipairs(table) do
            result[value[field_key]] = value[field_value]
        end
    -- readcsv_to_mapping产生的类型
    elseif is_table(table) then
        for _, value in pairs(table) do
            result[value[field_key]] = value[field_value]
        end
    -- 其他类型，出错！
    else
        return 
    end

    return result
end

--检查key是否有重复，默认第一列为key，默认array第一行为字段类型,
--第二行为字段名。
function checkkeys(array)
    if #array < 2 then
        return nil
    end

    local keys = {}

    --获取key
    for i = 3,#array do
        keys[i-2] = array[i][1]
    end

    local keys_map = {}
    for i = 1,#keys do

        --检查新现出的key是否已存在keys_map中，若有则key重复
        if not keys_map[keys[i]] then
            keys_map[keys[i]] = true
        else
            local error_info = string.format("the %s key repeat, please check", keys[i])
            assert(false, error_info)
            return nil
        end
    end

    return true
end

-- 从csv读取出来的数组中提取一列
function extract_column(csv_tables, column_name)
    -- mapping类型而非tables类型，需要作转化
    if not is_array(csv_tables) then
        if not is_table(csv_tables) then
            return nil
        else
            local temp = {}
            for _, value in pairs(csv_tables) do
                temp[#temp+1] = value
            end
            csv_tables = temp
        end

    end

    local column = {}
    for i, csv_record in ipairs(csv_tables) do
        column[i] = csv_record[column_name]
    end

    return column
end

--读取csv文件，返回mapping,以#开头的为注释
--正文第一行为字段的类型，第二行为字段名
function readcsv_to_mapping(file)
    return (array_to_mapping(readcsv(file)))
end

--读取csv文件,返回一个具有映射关系的table,以#开头的为注释
--正文第一行为字段的类型，第二行为字段名
function readcsv_to_tables(file)
    return (array_to_tables(readcsv(file)))
end

-- 读取csv文件，取出指定列的数据存入一个table数组
function readcsv_column_to_array(file, column_name)
    local csv_tables = readcsv_to_tables(file)
    local csv_column  = extract_column(csv_tables, column_name)
    return csv_column
end

--去除字符两端的空格
function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- 模块的入口执行
function create()
end

create()
