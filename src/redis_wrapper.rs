use td_rlua::{self, LuaPush, lua_State, LuaRead};
use libc;
use td_rredis::{Value, RedisError, RedisResult, Cmd, Msg};

static STATUS_SUFFIX: &'static str = "::STATUS";
static ERROR_SUFFIX: &'static str = "::ERROR";

pub struct RedisWrapperValue(pub Value);
pub struct RedisWrapperError(pub RedisError);
pub struct RedisWrapperResult(pub RedisResult<Value>);
pub struct RedisWrapperMsg(pub Msg);

pub struct RedisWrapperStringVec(pub Vec<String>);
pub struct RedisWrapperCmd(pub Cmd);

impl LuaPush for RedisWrapperValue {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        match self.0 {
            Value::Nil => ().push_to_lua(lua),
            Value::Int(val) => (val as u32).push_to_lua(lua),
            Value::Data(val) => {
                unsafe {
                    td_rlua::lua_pushlstring(lua, val.as_ptr() as *const libc::c_char, val.len())
                };
                1
            }
            Value::Bulk(mut val) => {
                let mut wrapper_val: Vec<RedisWrapperValue> = vec![];
                for v in val.drain(..) {
                    wrapper_val.push(RedisWrapperValue(v));
                }
                wrapper_val.push_to_lua(lua)
            }
            Value::Status(val) => {
                let val = val + STATUS_SUFFIX;
                val.push_to_lua(lua)
            }
            Value::Okay => {
                let val = "OK".to_string() + STATUS_SUFFIX;
                val.push_to_lua(lua)
            }
        }
    }
}

impl LuaPush for RedisWrapperError {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        let desc = format!("{}", self.0).to_string() + ERROR_SUFFIX;
        desc.push_to_lua(lua)
    }
}

impl LuaPush for RedisWrapperResult {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        match self.0 {
            Ok(val) => RedisWrapperValue(val).push_to_lua(lua),
            Err(err) => RedisWrapperError(err).push_to_lua(lua),
        }
    }
}

impl LuaPush for RedisWrapperMsg {
    fn push_to_lua(self, lua: *mut lua_State) -> i32 {
        unsafe {
            td_rlua::lua_newtable(lua);

            let payload: RedisResult<Value> = self.0.get_payload();
            if payload.is_ok() {
                "payload".push_to_lua(lua);
                RedisWrapperValue(payload.ok().unwrap()).push_to_lua(lua);
                td_rlua::lua_settable(lua, -3);
            }

            "channel".push_to_lua(lua);
            self.0.get_channel_name().push_to_lua(lua);
            td_rlua::lua_settable(lua, -3);

            let pattern: RedisResult<String> = self.0.get_pattern();
            if pattern.is_ok() {
                "pattern".push_to_lua(lua);
                pattern.ok().unwrap().push_to_lua(lua);
                td_rlua::lua_settable(lua, -3);
            }
            1
        }
    }
}


impl LuaRead for RedisWrapperStringVec {
    fn lua_read_at_position(lua: *mut lua_State, index: i32) -> Option<RedisWrapperStringVec> {
        let args = unsafe { td_rlua::lua_gettop(lua) - index.abs() + 1 };
        let mut strings = vec![];
        if args < 0 {
            return None;
        }
        for i in 0..args {
            let mut val: Option<String> = LuaRead::lua_read_at_position(lua, i + index);
            if val.is_none() {
                let bval: Option<bool> = LuaRead::lua_read_at_position(lua, i + index);
                if let Some(b) = bval {
                    if b {
                        val = Some("1".to_string());
                    } else {
                        val = Some("0".to_string());
                    }
                }
            }
            if val.is_none() {
                return None;
            }
            strings.push(val.unwrap());
        }
        Some(RedisWrapperStringVec(strings))
    }
}

impl LuaRead for RedisWrapperCmd {
    fn lua_read_at_position(lua: *mut lua_State, index: i32) -> Option<RedisWrapperCmd> {
        let strings: RedisWrapperStringVec = unwrap_or!(LuaRead::lua_read_at_position(lua, index),
                                                        return None);
        let mut cmd = Cmd::new();
        cmd.arg(strings.0);
        Some(RedisWrapperCmd(cmd))
    }
}
