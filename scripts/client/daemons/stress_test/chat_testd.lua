-- chat_testd.lua
-- Created by wugd
-- 聊天测试

-- 声明模块名
module("CHAT_TESTD", package.seeall);

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
    return math.random(1000, 5000)
end

-- 模块的入口函数
function create()

end

create();
