use td_rlua::{self, Lua, LuaPush};
use tunm_proto;
use super::EngineProtocol;
use {NetMsg, NetUtils};
use {NetResult, LuaWrapperTableValue};

pub struct ProtoRt;

impl EngineProtocol for ProtoRt {
    fn pack_protocol(lua: *mut td_rlua::lua_State, index: i32) -> Option<NetMsg> {
        let name: String = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, index), return None);
        let value = NetUtils::lua_convert_value(lua, index + 1);
        if value.is_none() {
            println!("data convert failed name = {:?}", name);
            return None;
        }
        let value = value.unwrap();
        let mut net_msg = NetMsg::new();
        unwrap_or!(tunm_proto::encode_proto(net_msg.get_buffer(), &name, value).ok(),
                   return None);
        net_msg.end_msg();
        if net_msg.len() > 0xFFFFFF {
            println!("pack message({}) size > 0xFFFF fail!", name);
            return None;
        }
        Some(net_msg)
    }

    fn unpack_protocol(lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<i32> {
        net_msg.set_read_data();
        if let Ok((name, val)) = tunm_proto::decode_proto(net_msg.get_buffer()) {
            name.push_to_lua(lua);
            LuaWrapperTableValue(val).push_to_lua(lua);
            return Ok(2);
        } else {
            return Ok(0);
        }
    }

    fn convert_string(lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<String> {
        net_msg.set_read_data();
        if let Ok((name, val)) = tunm_proto::decode_proto(net_msg.get_buffer()) {
            unsafe {
                td_rlua::lua_settop(lua, 0);
                name.push_to_lua(lua);
                LuaWrapperTableValue(val).push_to_lua(lua);
                let mut lua = Lua::from_existing_state(lua, false);
                let json: String = unwrap_or!(lua.exec_func("arg_to_encode"), return Ok("".to_string()));
                return Ok(json);
            }
        } else {
            return Ok("".to_string());
        }
    }
}