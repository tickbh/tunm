
PACKAGE_STATD = {}
setmetatable(PACKAGE_STATD, {__index = _G})
local _ENV = PACKAGE_STATD
-- 玩家接收到的包裹统计

MAX_PACKAGE_ONESEC = 30			-- 每秒最多允许30个包
MAX_PACKAGE_3SEC = 20			-- 3秒连续都超过这个包数，则踢掉

-- 初始化统计表
function init_stat_data()
	local t = 
	{
		last_second = os.time() ,			-- 当前统计秒内
		recv_count  = 0 ,								-- 寻前统计到的包累加
		last_second_recv_total = 0 ,						-- 保存前一秒统计值
		three_second_counter = 0 ,						-- 连续超过持续包统计的秒数
	}
	return t
end

function on_user_recv_package( user )
	local stat = user:query_temp("package_stat")
	if not stat then
		stat = init_stat_data()
		user:set_temp("package_stat", stat)
	end
	local ret = on_stat_recv_package(stat)
	if ret ~= 0 then
		user:connection_lost(true)
	end
end

function on_stat_recv_package( t )
	t.recv_count = t.recv_count + 1			-- 包数+1
	local second = os.time()
	if second ~= t.last_second then
		t.last_second = second
		t.last_second_recv_total = t.recv_count
		t.recv_count = 0
		
		if t.last_second_recv_total>= MAX_PACKAGE_3SEC then
			t.three_second_counter = t.three_second_counter + 1
		else
			t.three_second_counter = 0
		end
		
		if t.last_second_recv_total>MAX_PACKAGE_ONESEC then
			return 1			-- 超过每秒最大包数
		elseif t.three_second_counter>3 then
			return 2			-- 超过持续包数
		end
	end
	return 0
end

