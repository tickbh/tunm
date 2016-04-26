-- chat_testd.lua
-- Created by wugd
-- 聊天测试

-- 声明模块名
CHAT_TESTD = {}
setmetatable(CHAT_TESTD, {__index = _G})
local _ENV = CHAT_TESTD

-- 达到每个玩家的该模块间隔时间，则调用该函数
function operation(player)
    if not is_object(player) then
        return
    end
    local content = player:query("name") .. "__" .. tostring(math.random(10000, 99999))
    player:send_message(CMD_CHAT, CHAT_CHANNEL_WORLD, {send_content = content});
end

--毫秒
function random_interval()
    return math.random(10000, 300000)
end

-- 模块的入口函数
function create()

end

create();
