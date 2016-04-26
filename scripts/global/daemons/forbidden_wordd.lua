--forbidden_wordd.lua
--屏蔽字库
--create by wugd
FORBIDDEN_WORDD = {}
setmetatable(FORBIDDEN_WORDD, {__index = _G})
local _ENV = FORBIDDEN_WORDD

local forbidden_table = {}
local max_length = 1

function get_forbidden_list()
    return forbidden_table
end

function load_forbidden_word(file)
    local fp = io.open(get_full_path(file))
    forbidden_table = {}
    if fp then
        for line in fp:lines() do
            forbidden_table[line] = true
            max_length = math.max(max_length, string.len(line))
        end
        io.close(fp)
    end
end

function has_forbidden_word(content)
    local wordLen = string.len(content)
    for len=0, max_length do
        for i= 1, wordLen - len, 1 do
            local word = string.sub(content, i, i + len)
            if forbidden_table[word] then
                return word
            end
        end
    end
    return nil
end


function create()         
    load_forbidden_word("data/txt/banned_word.txt")
end

create()


