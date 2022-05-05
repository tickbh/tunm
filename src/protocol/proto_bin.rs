use td_rp::*;
use td_rlua::{self, LuaPush};
use super::EngineProtocol;
use {NetMsg, MSG_TYPE_BIN};
use {NetResult, LuaWrapperValue};
use LuaUtils;

pub struct ProtoBin;

impl EngineProtocol for ProtoBin {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        unsafe {
            let name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, index), return None);
            if td_rlua::lua_isstring(lua, index + 1) == 0 {
                return None;
            }

            let val = unwrap_or!(LuaUtils::read_str_to_vec(lua, index + 1), return None);
            let net_msg = NetMsg::new_by_detail(MSG_TYPE_BIN, name, &val[..]);
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


    fn convert_string(_: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<String> {
        net_msg.set_read_data();
        let _: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        let raw: String = try!(decode_str_raw(net_msg.get_buffer(), TYPE_STR)).into();
        return Ok(raw);
    }
}