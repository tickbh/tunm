use libc;
use std::mem;

use td_rlua::{self, Lua, LuaPush};
use super::EngineProtocol;
use {NetMsg, MSG_TYPE_JSON};

pub struct ProtoJson;

impl EngineProtocol for ProtoJson {
    ///depend lua function arg_to_encode
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        unsafe {
            for i in 1 .. index {
                td_rlua::lua_remove(lua, i);
            }

            let name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return None);

            let mut lua = Lua::from_existing_state(lua, false);
            let json: String = unwrap_or!(lua.exec_func("arg_to_encode"), return None);
            let net_msg = NetMsg::new_by_detail(MSG_TYPE_JSON, name, &json.as_bytes()[..]);
            Some(net_msg)
        }
    }

    fn unpack_message(lua: *mut td_rlua::lua_State, index: i32) -> i32 {
        0
    }
}