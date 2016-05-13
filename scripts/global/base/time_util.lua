--time_util.lua
--create by wugd

-- ---------------------------------------------------------------------------------------
--                                      时间相关
-- table: 0169CC48={
--  hour=7,
--  min=25,
--  wday=1,
--  day=13,
--  month=10,
--  year=2013,
--  sec=33,
--  yday=286,
--  isdst=false,
--  }

-- time_t -> table 
-- t = nil , 返回 当前时间
function time_to_table( t )
    return os.date( "*t" , t )
end

-- table -> time_t , tab=nil , 返回当前时间
function table_to_time( tab )
    return os.time( tab )
end

function time_to_string( t )
    local info = time_to_table(t)
    return string.format("%d-%02d %02d:%02d", info.month, info.day, info.hour, info.min)
end

function get_week_day(t)
    local tt = time_to_table(t or os.time())
    local wday = tt.wday - 1
    return (wday == 0) and 7 or wday
end

function daytime_to_string(t)
    t = t or os.time()
    if t == 0 then
        return "00:00"
    end
    local info = time_to_table(t)
    return string.format("%02d:%02d", info.hour, info.min)
end

function get_timezone()
  local now = os.time()
  return os.difftime(os.time(os.date("!*t", now)) , now )
end

timezone = get_timezone()
--以凌晨0点做为标准来算每一天
timestart = os.time({year=2013,month=1,day=1,hour=0, min=0,sec=0})
Day_Seconds     = (24*60*60)
Week_Seconds    = (7*Day_Seconds)

local MoneyDay = {31,28,31,30,31,30,31,31,30,31,30,31};

function is_lead_year(year)
    return (year % 4 == 0 and year % 100 ~= 0 or year % 400 == 0);
end

--当月的天数
function time_all_month_day( t )
    local timetable = time_to_table(t);
    local day = MoneyDay[timetable.month];
    if is_lead_year(timetable.year) and timetable.month == 2 then
        day = day + 1;
    end
    return day;
end

function time_month_day( t )
    local timetable = time_to_table(t)
    return timetable.day
end


-- 获取天数编号
function time_to_day_code( t )
    t = t or os.time()
    return math.floor( ( t-timestart ) / Day_Seconds )
end

function time_to_hour_code( t )
    if t==nil then
        t = os.time()
    end
    return math.floor( ( t-timestart ) / 3600 )
end

function time_to_fivemin_code( t )
    if t==nil then
        t = os.time()
    end
    return math.floor( ( t-timestart ) / 300 )
end

function time_to_fifteenmin_code( t )
    if t==nil then
        t = os.time()
    end
    return math.floor( ( t-timestart ) / 900 )
end

function time_to_code_by_sec(t, second)
    t = t or os.time()
    return math.floor( ( t-timestart ) / second )
end

function time_to_day_hour( t )
    return time_to_hour_code( t ) % 24
end

function parse_time_peroid( str )
    local d = 0
    if string.find( str , "d" ) then
        d = tonumber(string.match( str , "(%d+)d" ) )
    end
    local h = 0
    if string.find( str , "h" ) then
        h = tonumber(string.match( str , "(%d+)h" ) )
    end
    local m = 0
    if string.find( str , "m" ) then
        m = tonumber(string.match( str , "(%d+)m" ) )
    end
    local s = 0
    if string.find( str , "s" ) then
        s = tonumber(string.match( str , "(%d+)s" ) )
    end
    return d , h , m , s
end

function period_text_to_sec( str )
    local d,h,m,s = parse_time_peroid( str )
    return d * (24*60*60) + h*(60*60) + m*60 + s
end

function time_month_first_day(t)
    t = t or os.time()
    local timeTable = os.date( "*t" , t )
    timeTable["day"] = 1
    return time_to_day_code(table_to_time(timeTable))
end

function get_today_start_time(t)
    t = t or os.time()
    local timeTable = os.date( "*t" , t )
    timeTable["hour"] = 4
    timeTable["min"] = 0
    timeTable["sec"] = 0
    return table_to_time(timeTable)
end

function get_today_end_time(t)
    t = t or os.time()
    local timeTable = os.date( "*t" , t )
    timeTable["hour"] = 23
    timeTable["min"] = 59
    timeTable["sec"] = 59
    return table_to_time(timeTable)
end

function parse_time_period( str )
    local d = 0
    if string.find( str , "d" ) then
        d = tonumber(string.match( str , "(%d+)d" ) )
    end
    local h = 0
    if string.find( str , "h" ) then
        h = tonumber(string.match( str , "(%d+)h" ) )
    end
    local m = 0
    if string.find( str , "m" ) then
        m = tonumber(string.match( str , "(%d+)m" ) )
    end
    local s = 0
    if string.find( str , "s" ) then
        s = tonumber(string.match( str , "(%d+)s" ) )
    end
    return d , h , m , s
end

function period_text2sec( str )
    local d,h,m,s = parse_time_period( str )
    return d * (24*60*60) + h*(60*60) + m*60 + s
end

function is_same_day(time_compare, time_default)
    time_default = time_default or os.time()
    local cur_day = time_to_day_code(time_compare)
    local pre_day = time_to_day_code(time_default)
    return cur_day == pre_day
end

function get_day_diff(time_small, time_big)
    time_big = time_big or os.time()
    local cur_day = time_to_day_code(time_big)
    local pre_day = time_to_day_code(time_small)
    return cur_day - pre_day
end
