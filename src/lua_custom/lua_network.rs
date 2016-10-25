use std::mem;
use std::net::TcpStream;
use libc;

use td_rp;
use td_rlua::{self, Lua, LuaPush};
use td_revent::*;
use net2;
use {EventMgr, ServiceMgr, ProtocolMgr, NetMsg, NetConfig, NetUtils, ThreadUtils, HttpMgr, WebSocketMgr, SocketEvent};

static LUA_POOL_NAME: &'static str = "lua";

fn close_fd(fd: i32) {
    EventMgr::instance().add_kick_event(fd);
}

fn forward_to_port(fd: i32, net_msg: &mut NetMsg) -> i32 {
    if net_msg.len() < NetMsg::min_len() {
        println!("forward_to_port {:?}", net_msg.len());
        return -1;
    }
    let _ = net_msg.read_head();
    if net_msg.get_pack_len() != net_msg.len() as u32 {
        println!("forward_to_port {:?} == {:?}",
                 net_msg.get_pack_len(),
                 net_msg.len());
        return -1;
    }
    let success = EventMgr::instance().send_netmsg(fd, net_msg);
    if success {
        0
    } else {
        -1
    }
}

fn send_msg_to_port(fd: i32, net_msg: &mut NetMsg) -> i32 {
    let success = EventMgr::instance().send_netmsg(fd, net_msg);
    if success {
        0
    } else {
        -1
    }
}

extern "C" fn pack_message(lua: *mut td_rlua::lua_State) -> libc::c_int {

    let msg_type: u16 = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return 0);
    let net_msg = unwrap_or!(ProtocolMgr::instance().pack_protocol(lua, 2, msg_type), return 0);
    if net_msg.len() > 0xFFFFFF {
        println!("pack message({}) size > 0xFFFF fail!", net_msg.get_pack_name());
        return 0;
    }
    net_msg.push_to_lua(lua);
    1
}

extern "C" fn del_message(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let msg: &mut NetMsg = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return 0);
    unsafe { drop(Box::from_raw(msg)) };
    1
}


extern "C" fn pack_raw_message(lua: *mut td_rlua::lua_State) -> libc::c_int {
    unsafe {
        if td_rlua::lua_isstring(lua, 1) == 0 {
            return 0;
        }
        let mut size: libc::size_t = mem::uninitialized();
        let c_str_raw = td_rlua::lua_tolstring(lua, 1, &mut size);
        if c_str_raw.is_null() {
            return 0;
        }
        let val: Vec<u8> = Vec::from_raw_parts(c_str_raw as *mut u8, size, size);
        let net_msg = unwrap_or!(NetMsg::new_by_data(&val[..]).ok(), return 0);
        mem::forget(val);
        net_msg.get_pack_name().clone().push_to_lua(lua);
        net_msg.push_to_lua(lua);
        2
    }
}

fn get_message_type(msg: String) -> String {
    NetConfig::instance().get_proto_msg_type(&msg).map(|s| s.clone()).unwrap_or(String::new())
}

extern "C" fn listen_server(lua: *mut td_rlua::lua_State) -> libc::c_int {
    let bind_port: u16 = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(lua, 1), return 0);
    let bind_ip: Option<String> = td_rlua::LuaRead::lua_read_at_position(lua, 2);
    let bind_ip = bind_ip.unwrap_or("0.0.0.0".to_string());
    ServiceMgr::instance().start_listener(bind_ip, bind_port);
    0
}

fn stop_server() -> i32 {
    ServiceMgr::instance().stop_listener();
    EventMgr::instance().kick_all_socket();
    0
}

fn new_connect(ip: String, port: u16, _timeout: i32, cookie: u32) -> i32 {
    let pool = ThreadUtils::instance().get_pool(&LUA_POOL_NAME.to_string());
    pool.execute(move || {
        let ip = ip.trim_matches('\"');
        let stream = TcpStream::connect(&format!("{}:{}", ip.trim_matches('\"'), port)[..]);
        if stream.is_ok() {
            let stream = stream.unwrap();
            let mut peer_ip = "unkown_ip".to_string();
            if stream.peer_addr().is_ok() {
                peer_ip = format!("{}", stream.peer_addr().ok().unwrap());
            }
            let mut event = SocketEvent::new(stream.as_fd(), peer_ip, 0);
            event.set_cookie(cookie);
            EventMgr::instance().new_socket_event(event);
            net2::TcpStreamExt::set_nonblocking(&stream, true).ok().unwrap();
            EventMgr::instance()
                .get_event_loop()
                .add_event(EventEntry::new(stream.as_fd() as u32,
                                           FLAG_READ | FLAG_PERSIST,
                                           Some(ServiceMgr::read_write_callback),
                                           None));

            mem::forget(stream);
        } else {
            // TODO remove cookie
            println!("failed to connect server ip = {:?}, port = {:?}", ip, port);
        }
    });
    1
}

fn http_server_respone(cookie: u32, content: String) {
    HttpMgr::instance().http_server_respone(cookie, content);
}

fn http_get_request(cookie: u32, addr: String, url: String) {
    HttpMgr::instance().http_get_request(cookie, addr, url);
}

fn listen_http(url: String, port: u16) {
    HttpMgr::instance().start_listen(url, port);
}

fn listen_websocket(url: String, port: u16) {
    WebSocketMgr::instance().start_listen(url, port);
}

pub fn register_network_func(lua: &mut Lua) {
    lua.set("close_fd", td_rlua::function1(close_fd));
    lua.set("forward_to_port", td_rlua::function2(forward_to_port));
    lua.set("send_msg_to_port", td_rlua::function2(send_msg_to_port));

    lua.register("pack_message", pack_message);
    lua.register("del_message", del_message);
    lua.register("pack_raw_message", pack_raw_message);
    lua.set("get_message_type", td_rlua::function1(get_message_type));

    lua.register("listen_server", listen_server);
    lua.set("stop_server", td_rlua::function0(stop_server));
    lua.set("new_connect", td_rlua::function4(new_connect));

    lua.set("http_server_respone",
            td_rlua::function2(http_server_respone));
    lua.set("http_get_request", td_rlua::function3(http_get_request));
    lua.set("listen_http", td_rlua::function2(listen_http));
    lua.set("listen_websocket", td_rlua::function2(listen_websocket));


}
