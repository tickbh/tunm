use std::path::Path;
use std::collections::HashMap;

use std::net::UdpSocket;
use crypto;
use libc;
use td_rlua::{self, Lua, lua_State, LuaPush, LuaRead};
use {FileUtils, TelnetUtils, CommandMgr, LogUtils, EventMgr, TimeUtils};
use sys_info;
use {MaJiang, LuaEngine};

static ENCODE_MAP: &'static [u8; 32] = b"0123456789ACDEFGHJKLMNPQRSTUWXYZ";



fn lua_print(method : u8, val: String) {
    match method {
        1 => error!("{}", val),
        2 => warn!("{}", val),
        3 => info!("{}", val),
        4 => debug!("{}", val),
        5 => trace!("{}", val),
        _ => trace!("{}", val),
    };
    TelnetUtils::instance().new_message(val);
}

fn write_log(method : u8, val: String) {
    LogUtils::instance().append(method, &*val);
}

fn get_rid(server_id: u16, flag: Option<u8>) -> [u8; 12] {
    static mut RID_SEQUENCE: u32 = 0;
    static mut LAST_RID_TIME: u32 = 0;

    let mut rid = [0; 12];
    unsafe {
        RID_SEQUENCE += 1;
        RID_SEQUENCE &= 0x8FFF;

        // Get time as 1 p
        // Get time as 1 part, if time < _lastRidTime (may be carried), use _lastRidTime
        // Notice: There may be too many rids generated in 1 second, at this time
        if RID_SEQUENCE == 0 {
            LAST_RID_TIME += 1;
        }

        let ti = TimeUtils::get_time_s() as u32;
        if ti > LAST_RID_TIME {
            LAST_RID_TIME = ti;
        }
        let ti = LAST_RID_TIME - 1292342400; // 2010/12/15 0:0:0
        /* 60bits RID
         * 00000-00000-00000-00000-00000-00000 00000-00000-00 000-00000-00000-00000
         * -------------- TIME --------------- - SERVER_ID -- --- RID SEQUENCE ----
        */
        if flag.is_some() {
            rid[0] = ENCODE_MAP[(flag.unwrap() & 0x1F) as usize];
            rid[1] = ENCODE_MAP[((ti >> 23) & 0x1F) as usize];
            rid[2] = ENCODE_MAP[((ti >> 18) & 0x1F) as usize];
            rid[3] = ENCODE_MAP[((ti >> 13) & 0x1F) as usize];
            rid[4] = ENCODE_MAP[((ti >> 8) & 0x1F) as usize];
            rid[5] = ENCODE_MAP[((ti >> 3) & 0x1F) as usize]; //time

            // server_id[10..11]
            rid[6] = ENCODE_MAP[(((ti) & 0x7) | ((server_id >> 10) as u32 & 0x3)) as usize];
            rid[7] = ENCODE_MAP[((server_id >> 5) & 0x1F) as usize]; //[5..9]
            rid[8] = ENCODE_MAP[(server_id & 0x1F) as usize]; //[0..4]
            rid[9] = ENCODE_MAP[((RID_SEQUENCE >> 10) & 0x1F) as usize];
            rid[10] = ENCODE_MAP[((RID_SEQUENCE >> 5) & 0x1F) as usize];
            rid[11] = ENCODE_MAP[(RID_SEQUENCE & 0x1F) as usize];
        } else {
            rid[0] = ENCODE_MAP[((ti >> 25) & 0x1F) as usize];
            rid[1] = ENCODE_MAP[((ti >> 20) & 0x1F) as usize];
            rid[2] = ENCODE_MAP[((ti >> 15) & 0x1F) as usize];
            rid[3] = ENCODE_MAP[((ti >> 10) & 0x1F) as usize];
            rid[4] = ENCODE_MAP[((ti >> 5) & 0x1F) as usize];
            rid[5] = ENCODE_MAP[(ti & 0x1F) as usize]; //time
            rid[6] = ENCODE_MAP[((server_id >> 10) & 0x1F) as usize]; //
            rid[7] = ENCODE_MAP[((server_id >> 5) & 0x1F) as usize]; //server_id[2..11]
            rid[8] = ENCODE_MAP[((server_id) & 0x1F) as usize]; //server_id[0..2]
            rid[9] = ENCODE_MAP[((RID_SEQUENCE >> 10) & 0x1F) as usize];
            rid[10] = ENCODE_MAP[((RID_SEQUENCE >> 5) & 0x1F) as usize];
            rid[11] = ENCODE_MAP[(RID_SEQUENCE & 0x1F) as usize];
        }
    }
    rid
}

extern "C" fn get_next_rid(lua: *mut lua_State) -> libc::c_int {
    let server_id: u16 = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let flag: Option<u8> = LuaRead::lua_read_at_position(lua, 2);
    let rid = get_rid(server_id, flag);
    String::from_utf8_lossy(&rid).push_to_lua(lua);
    1
}


/// get the local ip address, return an `Option<String>`. when it fail, return `None`.
pub fn get_localip_addr() -> String {
    let socket = match UdpSocket::bind("0.0.0.0:0") {
        Ok(s) => s,
        Err(_) => return String::new(),
    };

    match socket.connect("8.8.8.8:80") {
        Ok(()) => (),
        Err(_) => return String::new(),
    };

    match socket.local_addr() {
        Ok(addr) => return addr.ip().to_string(),
        Err(_) => return String::new(),
    };
}


fn get_full_path(path: String) -> String {
    let full_path = FileUtils::instance().full_path_for_name(&*path);
    full_path.unwrap_or(path)
}

fn get_floder_files(path: String) -> Vec<String> {
    let mut files = vec![];
    let full_path = unwrap_or!(FileUtils::instance().full_path_for_name(&*path),
                               return vec![]);
    unwrap_or!(FileUtils::list_files(Path::new(&*full_path), &mut files, false).ok(),
               return vec![]);
    files
}

fn get_file_str(path: String) -> String {
    let full_path = unwrap_or!(FileUtils::instance().full_path_for_name(&*path),
                               String::new());
    unwrap_or!(FileUtils::get_file_str(&*full_path), String::new())
}

fn get_msg_type(name: String) -> String {
    // let proto = NetConfig::instance().get_proto_msg_type(&name);
    // proto.map(|s| s.clone()).unwrap_or("".to_string())
    String::new()
}

fn time_ms() -> u32 {
    TimeUtils::get_time_ms() as u32
}

fn block_read() -> String {
    let mut line = String::new();
    let _ = unwrap_or!(::std::io::stdin().read_line(&mut line).ok(), 0);
    line.trim_matches(|c| c == '\r' || c == '\n').to_string()
}

fn calc_str_md5(input: String) -> String {
    use crypto::digest::Digest;
    let mut md5 = crypto::md5::Md5::new();
    md5.input_str(&*input);
    md5.result_str()
}

fn start_command_input() {
    CommandMgr::start_command_input();
}

fn system_cpu_num() -> u32 {
    sys_info::cpu_num().ok().unwrap_or(0) 
}

fn system_cpu_speed() -> u32 {
    sys_info::cpu_speed().ok().unwrap_or(0) as u32
}

fn system_os_type() -> String {
    sys_info::os_type().ok().unwrap_or(String::new())
}

fn system_os_release() -> String {
    sys_info::os_release().ok().unwrap_or(String::new())
}

fn system_proc_total() -> u32 {
    sys_info::proc_total().ok().unwrap_or(0) as u32
}

fn system_loadavg() -> HashMap<String, f32> {
    let mut map = HashMap::new();
    if let Some(avg) = sys_info::loadavg().ok() {
        map.insert("one".to_string(), avg.one as f32);
        map.insert("five".to_string(), avg.five as f32);
        map.insert("fifteen".to_string(), avg.fifteen as f32);
    } else {
        map.insert("one".to_string(), 0 as f32);
        map.insert("five".to_string(), 0 as f32);
        map.insert("fifteen".to_string(), 0 as f32);
    }
    map
}

fn system_disk_info() -> HashMap<String, u32> {
    let mut map = HashMap::new();
    if let Some(avg) = sys_info::disk_info().ok() {
        map.insert("total".to_string(), avg.total as u32);
        map.insert("free".to_string(), avg.free as u32);
    } else {
        map.insert("total".to_string(), 0 as u32);
        map.insert("free".to_string(), 0 as u32);
    }
    map
}

fn system_mem_info() -> HashMap<String, u32> {
    let mut map = HashMap::new();
    if let Some(men) = sys_info::mem_info().ok() {
        map.insert("total".to_string(), men.total as u32);
        map.insert("free".to_string(), men.free as u32);
        map.insert("avail".to_string(), men.avail as u32);
        map.insert("buffers".to_string(), men.buffers as u32);
        map.insert("cached".to_string(), men.cached as u32);
        map.insert("swap_total".to_string(), men.swap_total as u32);
        map.insert("swap_free".to_string(), men.swap_free as u32);
    } else {
        map.insert("total".to_string(), 0 as u32);
        map.insert("free".to_string(), 0 as u32);
        map.insert("avail".to_string(), 0 as u32);
        map.insert("buffers".to_string(), 0 as u32);
        map.insert("cached".to_string(), 0 as u32);
        map.insert("swap_total".to_string(), 0 as u32);
        map.insert("swap_free".to_string(), 0 as u32);
    }
    map
}

fn native_all_socket_size() -> usize {
    EventMgr::instance().all_socket_size()
}

fn do_hotfix_file(path: String) -> i32 {
    LuaEngine::instance().do_hotfix_file(path)
}

fn shutdown_server() {
    EventMgr::instance().shutdown_event();
}

fn sleep_ms(ms: u32) {
    ::std::thread::sleep(::std::time::Duration::from_millis(ms as u64));
}

extern "C" fn native_check_hu(lua: *mut lua_State) -> libc::c_int {
    let poker_list: Vec<u8> = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let king_num: i32 = unwrap_or!(LuaRead::lua_read_at_position(lua, 2), return 0);
    let king_poker: u8 = unwrap_or!(LuaRead::lua_read_at_position(lua, 3), return 0);
    let is_spec_eat: bool = unwrap_or!(LuaRead::lua_read_at_position(lua, 4), return 0);
    if let Some((can_hu, hu_list, _other_list)) = MaJiang::check_can_hu(poker_list, king_num, king_poker, is_spec_eat) {
        can_hu.push_to_lua(lua);
        hu_list.push_to_lua(lua);
        return 2;
    }
    false.push_to_lua(lua);
    1
}

pub fn register_util_func(lua: &mut Lua) {
    lua.set("LUA_PRINT", td_rlua::function2(lua_print));
    lua.set("WRITE_LOG", td_rlua::function2(write_log));
    lua.register("GET_NEXT_RID", get_next_rid);
    lua.set("GET_FULL_PATH", td_rlua::function1(get_full_path));
    lua.set("GET_FILE_STR", td_rlua::function1(get_file_str));
    lua.set("GET_FLODER_FILES", td_rlua::function1(get_floder_files));
    lua.set("TIME_MS", td_rlua::function0(time_ms));
    lua.set("BLOCK_READ", td_rlua::function0(block_read));
    lua.set("GET_LOCALIP_ADDR", td_rlua::function0(get_localip_addr));
    
    lua.set("CALC_STR_MD5", td_rlua::function1(calc_str_md5));
    lua.set("START_COMMAND_INPUT",
            td_rlua::function0(start_command_input));
    lua.set("SYSTEM_CPU_NUM", td_rlua::function0(system_cpu_num));
    lua.set("SYSTEM_CPU_SPEED", td_rlua::function0(system_cpu_speed));
    lua.set("SYSTEM_OS_TYPE", td_rlua::function0(system_os_type));
    lua.set("SYSTEM_OS_RELEASE", td_rlua::function0(system_os_release));
    lua.set("SYSTEM_PROC_TOTAL", td_rlua::function0(system_proc_total));
    lua.set("SYSTEM_LOADAVG", td_rlua::function0(system_loadavg));
    lua.set("SYSTEM_DISK_INFO", td_rlua::function0(system_disk_info));
    lua.set("SYSTEM_MEM_INFO", td_rlua::function0(system_mem_info));
    lua.set("NATIVE_ALL_SOCKET_SIZE", td_rlua::function0(native_all_socket_size));
    lua.set("DO_HOTFIX_FILE", td_rlua::function1(do_hotfix_file));
    lua.register("NATIVE_CHECK_HU", native_check_hu);
    lua.set("SHUTDOWN_SERVER", td_rlua::function0(shutdown_server));
    lua.set("SLEEP_MS", td_rlua::function1(sleep_ms));
}
