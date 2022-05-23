use td_rlua::{self, lua_State};
use libc;
use std::mem;
use std::ptr;

pub struct LuaUtils {
    
}

impl LuaUtils {
    pub fn read_str_to_vec(lua: *mut lua_State, index: i32) -> Option<Vec<u8>> {
        let mut size: libc::size_t = unsafe { mem::MaybeUninit::uninit().assume_init() };
        let c_str_raw = unsafe { td_rlua::lua_tolstring(lua, index, &mut size) };
        if c_str_raw.is_null() {
            return None;
        }
        let mut dst = vec![0 as u8; size];
        unsafe {
            ptr::copy(c_str_raw as *mut u8, dst.as_mut_ptr(), size);
        }
        Some(dst)
    }
}