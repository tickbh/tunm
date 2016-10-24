use libc;
use std::mem;

use td_rlua::{self, Lua, LuaPush};
use super::EngineProtocol;
use NetMsg;

pub struct ProtoBin;

impl EngineProtocol for ProtoBin {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        unsafe {
            if td_rlua::lua_isstring(lua, index) == 0 {
                return None;
            }
            let mut size: libc::size_t = mem::uninitialized();
            let c_str_raw = td_rlua::lua_tolstring(lua, index, &mut size);
            if c_str_raw.is_null() {
                return None;
            }
            let val: Vec<u8> = Vec::from_raw_parts(c_str_raw as *mut u8, size, size);
            let net_msg = unwrap_or!(NetMsg::new_by_data(&val[..]).ok(), return None);
            mem::forget(val);
            Some(net_msg)
        }
    }

    fn unpack_message(lua: *mut td_rlua::lua_State, index: i32) -> i32 {
        0
    }
}