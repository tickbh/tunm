-- global_cookie.lua
-- 生成 cookie 的工具函数

local s_cookie = 0;
local i_cookie = 0;

-- 取得新的 cookie
function new_cookie()
    s_cookie = s_cookie + 1;
    s_cookie = bit32.band(s_cookie, 0xffff);
    s_cookie = (s_cookie == 0 and 1 or s_cookie);

    return s_cookie;
end

function new_int_cookie()
    i_cookie = i_cookie + 1;
    i_cookie = bit32.band(i_cookie, 0x0fffffff);
    i_cookie = (i_cookie == 0 and 1 or i_cookie);
    return i_cookie;
end

