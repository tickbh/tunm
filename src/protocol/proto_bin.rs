use libc;
use std::mem;
use td_rp;
use td_rp::*;
use td_rlua::{self, Lua, LuaPush};
use super::EngineProtocol;
use {NetMsg, MSG_TYPE_BIN};
use {NetResult, LuaWrapperValue};

pub struct ProtoBin;

impl EngineProtocol for ProtoBin {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        unsafe {
            let name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, index), return None);
            if td_rlua::lua_isstring(lua, index + 1) == 0 {
                return None;
            }
            let mut size: libc::size_t = mem::uninitialized();
            let c_str_raw = td_rlua::lua_tolstring(lua, index + 1, &mut size);
            if c_str_raw.is_null() {
                return None;
            }
            let val: Vec<u8> = Vec::from_raw_parts(c_str_raw as *mut u8, size, size);
            let net_msg = NetMsg::new_by_detail(MSG_TYPE_BIN, name, &val[..]);
            mem::forget(val);
            Some(net_msg)
        }
    }

    fn unpack_protocol(lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<i32> {
        net_msg.set_read_data();
        let name: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        let raw: Value = try!(decode_str_raw(net_msg.get_buffer(), TYPE_RAW));
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