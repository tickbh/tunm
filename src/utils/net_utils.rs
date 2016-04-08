use td_rlua::{self, lua_State, LuaRead};
use td_rp::*;
use libc;
use std::mem;
use std::collections::HashMap;
pub struct NetUtils;

impl NetUtils {
    pub fn lua_read_value(lua: *mut lua_State,
                          config: &Config,
                          index: i32,
                          arg: &str)
                          -> Option<Value> {
        let t = get_type_by_name(arg);
        let value = match t {
            TYPE_NIL => None,
            TYPE_U8 => {
                let val: u8 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_I8 => {
                let val: i8 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_U16 => {
                let val: u16 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_I16 => {
                let val: i16 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_U32 => {
                let val: u32 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_I32 => {
                let val: i32 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_FLOAT => {
                let val: f32 = unwrap_or!(LuaRead::lua_read_at_position(lua, index), return None);
                Some(Value::from(val))
            }
            TYPE_STR => {
                let val: String = unwrap_or!(LuaRead::lua_read_at_position(lua, index),
                                             return None);
                Some(Value::from(val))
            }
            TYPE_RAW => {
                let mut size: libc::size_t = unsafe { mem::uninitialized() };
                let c_str_raw = unsafe { td_rlua::lua_tolstring(lua, index, &mut size) };
                if c_str_raw.is_null() {
                    return None;
                }
                let val: Vec<u8> = unsafe { Vec::from_raw_parts(c_str_raw as *mut u8, size, size) };
                Some(Value::from(val))
            }
            TYPE_MAP => {
                let mut val: HashMap<String, Value> = HashMap::new();
                unsafe {
                    td_rlua::lua_pushnil(lua);
                    let t = if index < 0 {
                        index - 1
                    } else {
                        index
                    };
                    while td_rlua::lua_istable(lua, t) && td_rlua::lua_next(lua, t) != 0 {
                        let key: String = unwrap_or!(LuaRead::lua_read_at_position(lua, -2),
                                                     return None);
                        let field = config.get_field_by_name(&key);
                        if field.is_some() {
                            let sub_val = NetUtils::lua_read_value(lua,
                                                                   config,
                                                                   -1,
                                                                   &*field.unwrap().pattern);
                            if sub_val.is_none() {
                                return None;
                            }
                            val.insert(key, sub_val.unwrap());
                        }
                        td_rlua::lua_pop(lua, 1);
                    }
                }
                Some(Value::from(val))
            }
            TYPE_AU8 |
            TYPE_AI8 |
            TYPE_AU16 |
            TYPE_AI16 |
            TYPE_AU32 |
            TYPE_AI32 |
            TYPE_AFLOAT |
            TYPE_ASTR |
            TYPE_ARAW |
            TYPE_AMAP => {
                let mut val: Vec<Value> = Vec::new();
                unsafe {
                    if !td_rlua::lua_istable(lua, index) {
                        return None;
                    }
                    let len = td_rlua::lua_rawlen(lua, index);
                    for i in 1..(len + 1) {
                        td_rlua::lua_pushnumber(lua, i as f64);
                        let new_index = if index < 0 {
                            index - 1
                        } else {
                            index
                        };
                        td_rlua::lua_gettable(lua, new_index);
                        let sub_val = NetUtils::lua_read_value(lua,
                                                               config,
                                                               -1,
                                                               get_name_by_type(t - TYPE_STEP));
                        if sub_val.is_none() {
                            return None;
                        }
                        val.push(sub_val.unwrap());
                        td_rlua::lua_pop(lua, 1);
                    }
                }
                match t {
                    TYPE_AU8 => Some(Value::AU8(val)),
                    TYPE_AI8 => Some(Value::AI8(val)),
                    TYPE_AU16 => Some(Value::AU16(val)),
                    TYPE_AI16 => Some(Value::AI16(val)),
                    TYPE_AU32 => Some(Value::AU32(val)),
                    TYPE_AI32 => Some(Value::AI32(val)),
                    TYPE_AFLOAT => Some(Value::AFloat(val)),
                    TYPE_ASTR => Some(Value::AStr(val)),
                    TYPE_ARAW => Some(Value::ARaw(val)),
                    TYPE_AMAP => Some(Value::AMap(val)),
                    _ => None,
                }
            }
            _ => None,
        };
        value
    }

    pub fn lua_convert_value(lua: *mut lua_State,
                             config: &Config,
                             index: i32,
                             args: &Vec<String>)
                             -> Option<Vec<Value>> {
        let size = unsafe { td_rlua::lua_gettop(lua) - index + 1 };
        if size != args.len() as i32 {
            return None;
        }
        let mut val: Vec<Value> = Vec::new();
        for i in 0..size {
            let sub_val = NetUtils::lua_read_value(lua,
                                                   config,
                                                   i + index,
                                                   &*args.get(i as usize).unwrap());
            if sub_val.is_none() {
                return None;
            }
            val.push(sub_val.unwrap());
        }
        Some(val)
    }
}
