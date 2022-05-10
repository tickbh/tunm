use td_rlua::{self};
use {EngineProtocol, ProtoRt, ProtoJson, ProtoBin, ProtoText};
use {NetMsg, MSG_TYPE_TD, MSG_TYPE_BIN, MSG_TYPE_TEXT, MSG_TYPE_JSON, NetResult};

#[allow(dead_code)]
pub struct ProtocolMgr {
    td: ProtoRt,
    bin: ProtoBin,
    json: ProtoJson,
    text: ProtoText,
}

static mut EL: *mut ProtocolMgr = 0 as *mut _;
impl ProtocolMgr {
    pub fn instance() -> &'static mut ProtocolMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(ProtocolMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> ProtocolMgr {
        ProtocolMgr {
            td: ProtoRt {},
            bin: ProtoBin {},
            json: ProtoJson {},
            text: ProtoText {},
        }
    }

    pub fn pack_protocol(&mut self, lua: *mut td_rlua::lua_State, index: i32, msg_type: u8) -> Option<NetMsg> {
        match msg_type {
            MSG_TYPE_TD => ProtoRt::pack_protocol(lua, index),
            MSG_TYPE_JSON => ProtoJson::pack_protocol(lua, index),
            MSG_TYPE_BIN => ProtoBin::pack_protocol(lua, index),
            MSG_TYPE_TEXT => ProtoText::pack_protocol(lua, index),
            _ => None
        }
    }

    pub fn unpack_protocol(&mut self, lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> i32 {
        let msg_type = net_msg.get_msg_type();
        let ret = match msg_type {
            MSG_TYPE_TD => ProtoRt::unpack_protocol(lua, net_msg),
            MSG_TYPE_JSON => ProtoJson::unpack_protocol(lua, net_msg),
            MSG_TYPE_BIN => ProtoBin::unpack_protocol(lua, net_msg),
            MSG_TYPE_TEXT => ProtoText::unpack_protocol(lua, net_msg),
            _ => Ok(0)
        };
        ret.ok().unwrap_or(0)
    }


    pub fn convert_string(&mut self, lua: *mut td_rlua::lua_State, net_msg: &mut NetMsg) -> NetResult<String> {
        let msg_type = net_msg.get_msg_type();
        let ret = match msg_type {
            MSG_TYPE_TD => ProtoRt::convert_string(lua, net_msg),
            MSG_TYPE_JSON => ProtoJson::convert_string(lua, net_msg),
            MSG_TYPE_BIN => ProtoBin::convert_string(lua, net_msg),
            MSG_TYPE_TEXT => ProtoText::convert_string(lua, net_msg),
            _ => Ok("".to_string())
        };
        ret
    }
}
