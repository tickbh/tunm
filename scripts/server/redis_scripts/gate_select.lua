local gate_matches = KEYS[1]
local gate_prefix = ARGV[1]

local reply = redis.call("KEYS", gate_matches)
local ip, port, min = nil, nil, 9999999
local match_string = string.format("%s:([%%w.]*):(%%d+)",gate_prefix)
repeat
    if not reply then
        break
    end
    for _,value in ipairs(reply) do
        local cur_ip, cur_port = string.match(value, match_string)
        local reply_value = redis.call("get", value)
        if tonumber(cur_port) and (tonumber(reply_value) or 0) < min then
            ip, port, min = cur_ip, cur_port, tonumber(reply_value)
        end 
    end
until true

return {ip, port}
