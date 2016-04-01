-- string_util.lua
-- 字符帮助类

local empty_filter = " 　"
local empty_map = {}

function is_contain_empty_char(str)
    local map = get_str_map(str)
    for empty,_ in pairs(empty_map) do
        if map[empty] then
            return true
        end
    end
    return false
end

function get_utf8_count(str)
    local _, count = string.gsub(str, "[^\128-\193]", "")
    return count
end

function get_utf8_logic_len(str)
    local sum = 0
    local tab = get_str_table(str)
    for _,value in ipairs(tab) do
        if string.len(value) > 1 then
            sum = sum + 2
        else
            sum = sum + 1
        end
    end
    return sum
end

function get_str_table(str)
    local tab = {}
    for uchar in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        tab[#tab+1] = uchar
    end
    return tab
end

function get_str_map(str)
    local tab = {}
    for uchar in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        tab[uchar] = true
    end
    return tab
end


local function create()
    empty_map = get_str_map(empty_filter)
end

create()