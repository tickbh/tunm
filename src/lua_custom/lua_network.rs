use psocket::{TcpSocket};
use libc;
use td_rlua::{self, Lua, LuaPush};
use td_revent::*;
use psocket::SOCKET;
use ws;
use {EventMgr, ServiceMgr, ProtocolMgr, NetMsg, NetConfig, ThreadUtils, 
    HttpMgr, WebSocketMgr, WebsocketMyMgr, SocketEvent,
    LuaUtils, WebsocketClient, GlobalConfig};

static LUA_POOL_NAME: &'static str = "lua";
static TEST_WEBSOCKET_POOL_NAME: &'static str = "test_webscoket";

fn close_fd(fd: SOCKET) {
    EventMgr::instance().close_fd(fd, "Script Close".to_string());
}

fn forward_to_port(fd: SOCKET, net_msg: &mut NetMsg) -> i32 {
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

fn send_msg_to_port(fd: SOCKET, net_msg: &mut NetMsg) -> i32 {
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

// 用light_userdata, 降低整体lua的内存占有量, 尽量小的cc
extern "C" fn del_message(_lua: *mut td_rlua::lua_State) -> libc::c_int {
    let msg: &mut NetMsg = unwrap_or!(td_rlua::LuaRead::lua_read_at_position(_lua, 1), return 0);
    let _msg = unsafe { Box::from_raw(msg) };
    0
}


extern "C" fn pack_raw_message(lua: *mut td_rlua::lua_State) -> libc::c_int {
    unsafe {
        if td_rlua::lua_isstring(lua, 1) == 0 {
            return 0;
        }
        let val = unwrap_or!(LuaUtils::read_str_to_vec(lua, 1), return 0);
        let net_msg = unwrap_or!(NetMsg::new_by_data(&val[..]).ok(), return 0);
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
        let new_socket = TcpSocket::connect(&format!("{}:{}", ip.trim_matches('\"'), port)[..]);
        if new_socket.is_ok() {
            let new_socket = new_socket.unwrap();
            let mut peer_ip = "unkown_ip".to_string();
            if new_socket.peer_addr().is_ok() {
                peer_ip = format!("{}", new_socket.peer_addr().ok().unwrap());
            }
            let mut event = SocketEvent::new(new_socket.as_raw_socket(), peer_ip, 0);
            event.set_cookie(cookie);
            event.set_local(true);
            EventMgr::instance().new_socket_event(event);
            // net2::TcpStreamExt::set_nonblocking(&stream, true).ok().unwrap();

            let socket = new_socket.as_raw_socket();
            let ev = EventMgr::instance().get_event_loop();
            let buffer = ev.new_buff(new_socket);
            let _ = ev.register_socket(
                buffer,
                EventEntry::new_event(
                    socket,
                    EventFlags::FLAG_READ | EventFlags::FLAG_PERSIST,
                    Some(ServiceMgr::server_read_callback),
                    None,
                    Some(ServiceMgr::server_end_callback),
                    None,
                ),
            );
            
            // TcpMgr::instance().insert_stream(stream.as_fd(), stream);
        } else {
            // TODO remove cookie
            println!("failed to connect server ip = {:?}, port = {:?}", ip, port);
        }
    });
    1
}


fn new_websocket_connect(ip: String, port: u16, _timeout: i32, cookie: u32) -> i32 {
    let pool = ThreadUtils::instance().get_default_pool(&TEST_WEBSOCKET_POOL_NAME.to_string(), 100);
    pool.execute(move || {
        let ip = ip.trim_matches('\"');
        ws::connect(&format!("ws://{}:{}", ip.trim_matches('\"'), port)[..], |sender| {
            WebsocketClient {
                out: sender,
                port: port,
                cookie: cookie,
            }
        }).unwrap();
    });
    1
}

fn http_server_respone(cookie: u32, content: String) {
    HttpMgr::instance().http_server_respone(cookie, content);
}

fn http_get_request(cookie: u32, addr: String, url: String) {
    HttpMgr::instance().http_get_request(cookie, addr, url);
}

fn http_post_request(cookie: u32, addr: String, url: String, body: String) {
    HttpMgr::instance().http_post_request(cookie, addr, url, body);
}

fn listen_http(url: String, port: u16) {
    HttpMgr::instance().start_listen(url, port);
}

fn listen_mio_websocket(url: String, port: u16) {
    WebSocketMgr::instance().start_listen(url, port);
}

fn listen_websocket(url: String, port: u16) {
    WebsocketMyMgr::instance().start_listen(url, port);
}

fn update_net_message(path: String) {
    let success = {
        if path.len() == 0 {
            let global_config = GlobalConfig::instance();
            NetConfig::change_by_file(&*global_config.net_info)
        } else {
            NetConfig::change_by_file(&*path)
        }
    };
    println!("update_net_message {:?}", success);
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
    lua.set("new_websocket_connect", td_rlua::function4(new_websocket_connect));

    lua.set("http_server_respone",
            td_rlua::function2(http_server_respone));
    lua.set("http_get_request", td_rlua::function3(http_get_request));
    lua.set("http_post_request", td_rlua::function4(http_post_request));

    lua.set("listen_http", td_rlua::function2(listen_http));
    lua.set("listen_websocket", td_rlua::function2(listen_websocket));
    lua.set("listen_mio_websocket", td_rlua::function2(listen_mio_websocket));

    lua.set("update_net_message", td_rlua::function1(update_net_message));
}
