use libc;
use std::mem;
use td_rp;
use td_rp::*;
use td_rlua::{self, Lua, LuaPush};
use super::EngineProtocol;
use {NetMsg, MSG_TYPE_JSON};
use {NetResult, LuaWrapperValue};

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
            println!("json = {}", json);
            let net_msg = NetMsg::new_by_detail(MSG_TYPE_JSON, name, &json.as_bytes()[..]);
            Some(net_msg)
        }
    }

    fn unpack_protocol(lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<i32> {
        net_msg.set_read_data();
        println!("net_msg len = {}", net_msg.get_pack_len());
        let name: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        println!("name len = {}", name);
        let raw: Value = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR));
        println!("raw len = {:?}", raw);
        name.push_to_lua(lua);
        LuaWrapperValue(raw).push_to_lua(lua);
        return Ok(2);
    }

    fn convert_string(lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<String> {
        net_msg.set_read_data();
        let name: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        let raw: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        return Ok(raw);
    }
}