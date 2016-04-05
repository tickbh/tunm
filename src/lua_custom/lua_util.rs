use std::path::Path;
use time;
use crypto;
use crypto::md5::Md5;
use libc;
use td_rlua::{self, Lua, lua_State, LuaPush, LuaRead};
use {FileUtils, NetConfig, TelnetUtils, CommandMgr};

static ENCODE_MAP : &'static [u8; 32] = b"0123456789ACDEFGHJKLMNPQRSTUWXYZ";


fn lua_print(mut val : String) {
    if val.len() > 1000 {
        let val : String = val.drain(..1000).collect();
        // let val = String::from_utf8_lossy(&val);
        println!("{}", val);
        TelnetUtils::instance().new_message(val);
    } else {
        println!("{}", val);
        TelnetUtils::instance().new_message(val);
    }

}

fn write_log(_val : String) {
    // println!("{}", val);   
}

fn get_rid(server_id : u16, flag : Option<u8>) -> [u8; 12] {
    static mut rid_sequence : u32 = 0;
    static mut last_rid_time : u32 = 0;

    let mut rid = [ 0; 12];
    unsafe {
        rid_sequence += 1;
        rid_sequence &= 0x8FFF;

        // Get time as 1 p
        // Get time as 1 part, if time < _lastRidTime (may be carried), use _lastRidTime
        // Notice: There may be too many rids generated in 1 second, at this time
        if rid_sequence == 0 {
            last_rid_time += 1;
        }

        let ti = time::get_time().sec as u32;
        if ti > last_rid_time {
            last_rid_time = ti;
        }
        println!("last_rid_time is {}", time::precise_time_s());
        println!("last_rid_time is {}", last_rid_time);
        let ti = last_rid_time - 1292342400; // 2010/12/15 0:0:0
        /* 60bits RID
         * 00000-00000-00000-00000-00000-00000 00000-00000-00 000-00000-00000-00000
         * -------------- TIME --------------- - SERVER_ID -- --- RID SEQUENCE ----
        */
        if flag.is_some() {
            rid[0] = ENCODE_MAP[(flag.unwrap() & 0x1F) as usize ];
            rid[1] = ENCODE_MAP[((ti >> 23) & 0x1F) as usize];
            rid[2] = ENCODE_MAP[((ti >> 18) & 0x1F) as usize];
            rid[3] = ENCODE_MAP[((ti >> 13) & 0x1F) as usize];
            rid[4] = ENCODE_MAP[((ti >>  8) & 0x1F) as usize];
            rid[5] = ENCODE_MAP[((ti >>  3) & 0x1F) as usize]; //time
            rid[6] = ENCODE_MAP[(((ti)      & 0x7) | ((server_id >> 10) as u32 & 0x3)) as usize]; //server_id[10..11]
            rid[7] = ENCODE_MAP[((server_id >> 5) & 0x1F) as usize]; //[5..9]
            rid[8] = ENCODE_MAP[(server_id        & 0x1F) as usize]; //[0..4]
            rid[9] = ENCODE_MAP[((rid_sequence >> 10)& 0x1F) as usize]; 
            rid[10]= ENCODE_MAP[((rid_sequence >> 5) & 0x1F) as usize]; 
            rid[11]= ENCODE_MAP[(rid_sequence        & 0x1F) as usize]; 
        }
        else {
            rid[0] = ENCODE_MAP[((ti >> 25) & 0x1F) as usize];
            rid[1] = ENCODE_MAP[((ti >> 20) & 0x1F) as usize];
            rid[2] = ENCODE_MAP[((ti >> 15) & 0x1F) as usize];
            rid[3] = ENCODE_MAP[((ti >> 10) & 0x1F) as usize];
            rid[4] = ENCODE_MAP[((ti >>  5) & 0x1F) as usize];
            rid[5] = ENCODE_MAP[(ti         & 0x1F) as usize]; //time
            rid[6] = ENCODE_MAP[((server_id >> 10) & 0x1F) as usize]; //
            rid[7] = ENCODE_MAP[((server_id >>  5) & 0x1F) as usize]; //server_id[2..11]
            rid[8] = ENCODE_MAP[((server_id      ) & 0x1F) as usize]; //server_id[0..2]
            rid[9] = ENCODE_MAP[((rid_sequence >> 10)& 0x1F) as usize]; 
            rid[10]= ENCODE_MAP[((rid_sequence >> 5) & 0x1F) as usize]; 
            rid[11]= ENCODE_MAP[(rid_sequence        & 0x1F) as usize]; 
        }
    }
    rid
}

extern "C" fn get_next_rid(lua : *mut lua_State) -> libc::c_int {
    let server_id : u16 = unwrap_or!(LuaRead::lua_read_at_position(lua, 1), return 0);
    let flag : Option<u8> = LuaRead::lua_read_at_position(lua, 2); 
    let rid = get_rid(server_id, flag);
    String::from_utf8_lossy(&rid).push_to_lua(lua);    
    1
}

fn get_full_path(path : String) -> String {
    let full_path = FileUtils::instance().full_path_for_name(&*path);
    full_path.unwrap_or(path)
}

fn get_floder_files(path : String) -> Vec<String> {
    let mut files = vec![];
    let full_path = unwrap_or!(FileUtils::instance().full_path_for_name(&*path), return vec![]);
    unwrap_or!(FileUtils::list_files(Path::new(&*full_path), &mut files, false).ok(), return vec![]);
    files
}

fn get_file_str(path : String) -> String {
    let full_path = unwrap_or!(FileUtils::instance().full_path_for_name(&*path), String::new());
    unwrap_or!(FileUtils::get_file_str(&*full_path), String::new())
}

fn get_msg_type(name : String) -> String {
    let proto = NetConfig::instance().get_proto_msg_type(&name);
    proto.map(|s| s.clone()).unwrap_or("".to_string())
}

fn time_ms() -> u32 {
    (time::precise_time_ns() / 1000_000) as u32 
}

fn block_read() -> String {
    let mut line = String::new();
    let _ = unwrap_or!(::std::io::stdin().read_line(&mut line).ok(), 0);
    line
}

fn calc_str_md5(input : String) -> String {
    use crypto::digest::Digest;
    let mut md5 = crypto::md5::Md5::new();
    md5.input_str(&*input);
    md5.result_str()
}

fn start_command_input() {
    CommandMgr::start_command_input();
}

pub fn register_util_func(lua : &mut Lua) {
    lua.set("lua_print", td_rlua::function1(lua_print));
    lua.set("write_log", td_rlua::function1(write_log));
    lua.register("get_next_rid", get_next_rid);
    lua.set("get_full_path", td_rlua::function1(get_full_path));
    lua.set("get_file_str", td_rlua::function1(get_file_str));
    lua.set("get_floder_files", td_rlua::function1(get_floder_files));
    lua.set("get_msg_type", td_rlua::function1(get_msg_type));
    lua.set("time_ms", td_rlua::function0(time_ms));
    lua.set("block_read", td_rlua::function0(block_read));
    lua.set("calc_str_md5", td_rlua::function1(calc_str_md5));
    lua.set("start_command_input", td_rlua::function0(start_command_input));

}
