use {NetMsg, NetConfig, FileUtils};
use td_rlua::{self, Lua};
use libc;
use td_rp;
use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use td_rredis::{RedisResult, Value};
use super::{LuaWrapperTableValue, RedisWrapperResult};

static mut el: *mut LuaEngine = 0 as *mut _;
/// the type of lua call type
enum LuaElem {
    /// fd, msg
    Message(i32, NetMsg),
    /// cookie, ret, err_msg, msg
    DbResult(u32, i32, Option<String>, Option<NetMsg>),
    /// cookie, value
    RedisResult(u32, Option<RedisResult<Value>>),
    /// cookie, new_fd, client_ip, server_port
    NewConnection(u32, i32, String, u16),
    /// fd
    LostConnection(i32),
    /// func_str
    ExecString(String),
    /// Args fuc
    ArgsFunc(String, Vec<String>),
}

/// the enterface to call lua, it store the lua state and exec list
pub struct LuaEngine {
    exec_list: Vec<LuaElem>,
    lua: Lua,
    mutex: Arc<ReentrantMutex<i32>>,
}

/// custom lua load func
extern "C" fn load_func(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let path: String = unwrap_or!(td_rlua::LuaRead::lua_read(lua), return 0);
    let full_path = unwrap_or!(FileUtils::instance().full_path_for_name(&*path), path);
    let full_path = full_path.trim_matches('\"');
    let mut lua = Lua::from_existing_state(lua, false);
    lua.load_file(&*full_path)
}

impl LuaEngine {
    pub fn instance() -> &'static mut LuaEngine {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(LuaEngine::new(Lua::new())));
            }
            &mut *el
        }
    }

    pub fn new(mut lua: Lua) -> LuaEngine {
        lua.openlibs();
        lua.add_lualoader(load_func);
        lua.enable_hotfix();
        LuaEngine {
            exec_list: vec![],
            lua: lua,
            mutex: Arc::new(ReentrantMutex::new(0)),
        }
    }

    pub fn get_lua(&mut self) -> &mut Lua {
        &mut self.lua
    }

    pub fn execute_lua(&mut self) -> bool {
        let temp_list: Vec<LuaElem>;
        {
            let _guard = self.mutex.lock().unwrap();
            temp_list = self.exec_list.drain(..).collect();
        }
        for elem in temp_list {
            let _ = match elem {
                LuaElem::Message(fd, net_msg) => self.execute_message(fd, net_msg),
                LuaElem::DbResult(cookie, ret, err_msg, net_msg) => {
                    self.execute_db_result(cookie, ret, err_msg, net_msg)
                }
                LuaElem::RedisResult(cookie, result) => self.execute_redis_result(cookie, result),
                LuaElem::NewConnection(cookie, new_fd, client_ip, server_port) => {
                    self.execute_new_connect(cookie, new_fd, client_ip, server_port)
                }
                LuaElem::LostConnection(lost_fd) => self.execute_lost_connect(lost_fd),
                LuaElem::ExecString(func_str) => self.execute_string(func_str),
                LuaElem::ArgsFunc(func, args) => self.execute_args_func(func, args),
            };
        }
        true
    }

    pub fn apply_new_connect(&mut self,
                             cookie: u32,
                             new_fd: i32,
                             client_ip: String,
                             server_port: u16) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::NewConnection(cookie, new_fd, client_ip, server_port));
    }

    pub fn apply_lost_connect(&mut self, lost_fd: i32) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::LostConnection(lost_fd));
    }

    pub fn apply_db_result(&mut self,
                           cookie: u32,
                           ret: i32,
                           err_msg: Option<String>,
                           net_msg: Option<NetMsg>) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::DbResult(cookie, ret, err_msg, net_msg));
    }

    pub fn apply_redis_result(&mut self, cookie: u32, result: Option<RedisResult<Value>>) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::RedisResult(cookie, result));
    }

    pub fn apply_message(&mut self, fd: i32, net_msg: NetMsg) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::Message(fd, net_msg));
    }

    pub fn apply_exec_string(&mut self, func_str: String) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::ExecString(func_str));
    }


    pub fn apply_args_func(&mut self, func: String, args: Vec<String>) {
        let _guard = self.mutex.lock().unwrap();
        self.exec_list.push(LuaElem::ArgsFunc(func, args));
    }

    pub fn execute_new_connect(&mut self,
                               cookie: u32,
                               new_fd: i32,
                               client_ip: String,
                               server_port: u16)
                               -> i32 {
        self.lua.exec_func4("cmd_new_connection", cookie, new_fd, client_ip, server_port)
    }

    pub fn execute_lost_connect(&mut self, lost_fd: i32) -> i32 {
        self.lua.exec_func1("cmd_connection_lost", lost_fd)
    }

    pub fn execute_db_result(&mut self,
                             cookie: u32,
                             ret: i32,
                             err_msg: Option<String>,
                             net_msg: Option<NetMsg>)
                             -> i32 {
        if ret != 0 {
            self.lua.exec_func3("msg_db_result",
                                cookie,
                                ret,
                                err_msg.unwrap_or("err msg detail miss".to_string()))
        } else {
            if net_msg.is_some() {
                // if let Some(net_msg) = net_msg.as_mut() {
                let mut net_msg = net_msg.unwrap();
                net_msg.set_read_data();
                let instance = NetConfig::instance();
                if let Ok((_, val)) = td_rp::decode_proto(net_msg.get_buffer(), instance) {
                    self.lua.exec_func3("msg_db_result", cookie, ret, LuaWrapperTableValue(val))
                } else {
                    self.lua.exec_func3("msg_db_result", cookie, -2, "analyse data failed")
                }
            } else {
                self.lua.exec_func3("msg_db_result", cookie, ret, LuaWrapperTableValue(vec![]))
            }
        }
    }

    pub fn execute_redis_result(&mut self, cookie: u32, result: Option<RedisResult<Value>>) -> i32 {
        if result.is_none() {
            self.lua.exec_func1("msg_redis_result", cookie)
        } else {
            self.lua.exec_func2("msg_redis_result",
                                cookie,
                                RedisWrapperResult(result.unwrap()))
        }
    }

    pub fn execute_message(&mut self, fd: i32, mut net_msg: NetMsg) -> i32 {
        net_msg.set_read_data();
        unwrap_or!(net_msg.read_head().ok(), return -1);
        self.lua.exec_func3("global_dispatch_command",
                            fd,
                            net_msg.get_pack_name().clone(),
                            net_msg)
    }

    pub fn execute_string(&mut self, func_str: String) -> i32 {
        self.lua.exec_func1("run_string", func_str)
    }

    pub fn execute_args_func(&mut self, func: String, args: Vec<String>) -> i32 {
        match args.len() {
            0 => self.lua.exec_func0(func),
            1 => self.lua.exec_func1(func, &*args[0]),
            2 => self.lua.exec_func2(func, &*args[0], &*args[1]),
            3 => self.lua.exec_func3(func, &*args[0], &*args[1], &*args[2]),
            4 => self.lua.exec_func4(func, &*args[0], &*args[1], &*args[2], &*args[3]),
            5 => self.lua.exec_func5(func, &*args[0], &*args[1], &*args[2], &*args[3], &*args[4]),
            6 => {
                self.lua.exec_func6(func,
                                    &*args[0],
                                    &*args[1],
                                    &*args[2],
                                    &*args[3],
                                    &*args[4],
                                    &*args[5])
            }
            7 => {
                self.lua.exec_func7(func,
                                    &*args[0],
                                    &*args[1],
                                    &*args[2],
                                    &*args[3],
                                    &*args[4],
                                    &*args[5],
                                    &*args[6])
            }
            _ => -1,
        }
    }

    pub fn convert_excute_string(mut ori: String) -> String {
        if ori.len() == 0 {
            return ori;
        }

        if let Some(index) = ori.find('\'') {
            if index == 0 {
                let t: String = ori.drain(1..).collect();
                return format!("trace(\"%o\", {})", t);
            }
        }

        return ori;
    }
}
