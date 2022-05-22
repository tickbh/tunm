use std::collections::HashMap;
use std::io::prelude::*;
use std::boxed::Box;
use psocket::SOCKET;
use std::any::Any;

use tunm_timer::{Factory, RetTimer, Timer, Handler};
use crate::{MioEventMgr};

use SocketEvent;
use LuaEngine;
use NetMsg;
use WebSocketMgr;
use WebsocketMyMgr;
use LogUtils;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use tunm_proto::{self, Buffer, decode_number};
use td_revent::*;

static mut EL: *mut EventMgr = 0 as *mut _;
static mut READ_DATA: [u8; 65536] = [0; 65536];
pub struct EventMgr {
    connect_ids: HashMap<SOCKET, SocketEvent>,
    mutex: Arc<ReentrantMutex<i32>>,
    event_loop: EventLoop,
    lua_exec_id: u32,
    exit: bool,
}

pub struct TimeHandle {
    timer_name: String,
}

impl Factory for TimeHandle {
    fn on_trigger(&mut self, timer: &mut Timer<Self>, id: u64) -> RetTimer {
        if self.timer_name == "MIO" {
            let _ = MioEventMgr::instance().run_one_server();
        }
        println!("ontigger = {:}", id);
        RetTimer::Ok
    }
}

impl EventMgr {
    pub fn new() -> EventMgr {
        EventMgr {
            connect_ids: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0)),
            event_loop: EventLoop::new().ok().unwrap(),
            lua_exec_id: 0,
            exit: false,
        }
    }

    pub fn instance() -> &'static mut EventMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(EventMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn get_event_loop(&mut self) -> &mut EventLoop {
        &mut self.event_loop
    }

    pub fn shutdown_event(&mut self) {
        self.exit = true;
        self.event_loop.shutdown();
    }

    pub fn is_exit(&self) -> bool {
        self.exit
    }

    pub fn new_socket_event(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.as_raw_socket(),
                                                ev.get_client_ip(),
                                                ev.get_server_port(),
                                                ev.is_websocket());
        self.connect_ids.insert(ev.as_raw_socket(), ev);
        true
    }

    pub fn receive_socket_event(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        self.connect_ids.insert(ev.as_raw_socket(), ev);
        true
    }

    pub fn kick_socket(&mut self, sock: SOCKET) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        let _sock_ev = self.connect_ids.remove(&sock);
        let _ = self.event_loop.unregister_socket(sock);
    }

    pub fn write_data(&mut self, fd: SOCKET, data: &[u8]) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }
        let event_loop = EventMgr::instance().get_event_loop();
        match event_loop.send_socket(&fd, data) {
            Ok(_len) => return true,
            Err(_) => return false,
        }
    }

    pub fn send_netmsg(&mut self, fd: SOCKET, net_msg: &mut NetMsg) -> bool {
        let _ = net_msg.read_head();
        if net_msg.get_pack_len() != net_msg.len() as u32 {
            println!("error!!!!!!!! net_msg.get_pack_len() = {:?}, net_msg.len() = {:?}", net_msg.get_pack_len(), net_msg.len());
            return false;
        }
        let (is_websocket, is_mio) = {
            let mutex = self.mutex.clone();
            let _guard = mutex.lock().unwrap();
            if !self.connect_ids.contains_key(&fd) {
                return false;
            } else {
                let socket_event = self.connect_ids.get_mut(&fd).unwrap();
                (socket_event.is_websocket(), socket_event.is_mio())
            }
        };

        if is_websocket {
            if is_mio {
                return WebSocketMgr::instance().send_message(fd as usize, net_msg);
            } else {
                return WebsocketMyMgr::instance().send_message(fd, net_msg);
            }
        } else {
            let data = net_msg.get_buffer().get_data();
            self.write_data(fd, data)
        }
    }

    pub fn close_fd(&mut self, fd: SOCKET, reason: String) -> bool {
        let (is_websocket, is_mio) = {
            let mutex = self.mutex.clone();
            let _guard = mutex.lock().unwrap();
            if !self.connect_ids.contains_key(&fd) {
                return false;
            } else {
                let socket_event = self.connect_ids.get_mut(&fd).unwrap();
                (socket_event.is_websocket(), socket_event.is_mio())
            }
        };

        if is_websocket {
            if is_mio {
                return WebSocketMgr::instance().close_fd(fd as usize);
            } else {
                return WebsocketMyMgr::instance().close_fd(fd);
            }
        } else {
            self.add_kick_event(fd, reason);
        }
        true
    }

    pub fn get_socket_event(&mut self, fd: SOCKET) -> Option<&mut SocketEvent> {
    let _guard = self.mutex.lock().unwrap();
        self.connect_ids.get_mut(&fd)
    }

    pub fn data_recieved(&mut self, fd: SOCKET, data: &[u8]) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = EventMgr::instance().get_socket_event(fd);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let _ = socket_event.get_in_buffer().write(data);
        self.try_dispatch_message(fd);
    }

    pub fn try_dispatch_message(&mut self, fd: SOCKET) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = EventMgr::instance().get_socket_event(fd);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let buffer_len = socket_event.get_in_buffer().len();
        let buffer = socket_event.get_in_buffer();
        loop {
            let message: Option<Vec<u8>> = EventMgr::get_next_message(buffer);
            if message.is_none() {
                break;
            }
            let msg = NetMsg::new_by_data(&message.unwrap()[..]);
            if msg.is_err() {
                println!("message error kick fd {:?} msg = {:?}, buffer = {}", fd, msg.err(), buffer_len);
                self.add_kick_event(fd, "Message Dispatch Error".to_string());
                break;
            }

            LuaEngine::instance().apply_message(fd, msg.ok().unwrap());
        }
    }

    fn get_next_message(buffer: &mut Buffer) -> Option<Vec<u8>> {
        if buffer.len() < NetMsg::min_len() as usize {
            return None;
        }
        let rpos = buffer.get_rpos();
        let mut length: u32 = unwrap_or!(decode_number(buffer, tunm_proto::TYPE_U32).ok(), return None)
                              .into();
        buffer.set_rpos(rpos);
        length = unsafe { ::std::cmp::min(length, READ_DATA.len() as u32) };
        if buffer.len() - rpos < length as usize {
            return None;
        }
        Some(buffer.drain_collect(length as usize))
    }

    pub fn exist_socket_event(&self, fd: SOCKET) -> bool {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.contains_key(&fd)
    }

    pub fn all_socket_size(&self) -> usize {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.len()
    }

    pub fn kick_all_socket(&self) {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.len();
    }

    pub fn remove_connection(&mut self, fd:SOCKET) {
        let _guard = self.mutex.lock().unwrap();
        let _sock_ev = unwrap_or!(self.connect_ids.remove(&fd), return);
    }

    pub fn add_kick_event(&mut self, fd: SOCKET, reason: String) {
        println!("add kick event fd = {} reason = {}", fd, reason);
        let websocket_fd = {
            let _guard = self.mutex.lock().unwrap();
            let info = format!("Close Fd {} by Reason {}", fd, reason);
            println!("{}", info);
            LogUtils::instance().append(2, &*info);

            let sock_ev = unwrap_or!(self.connect_ids.remove(&fd), return);
            if !sock_ev.is_websocket() || !sock_ev.is_mio() {
                // self.event_loop.unregister_socket(sock_ev.as_raw_socket(), EventFlags::all());
                self.event_loop
                    .add_timer(EventEntry::new_timer(20,
                                                     false,
                                                     Some(Self::kick_callback),
                                                     Some(Box::new(sock_ev))));
                return;
            }
            sock_ev.get_socket_fd()
        };

        LuaEngine::instance().apply_lost_connect(websocket_fd as SOCKET, "服务端关闭".to_string());
    }

    //由事件管理主动推送关闭的调用
    pub fn notify_connect_lost(&mut self, socket: SOCKET) {
        let _sock_ev = unwrap_or!(self.connect_ids.remove(&socket), return);
        LuaEngine::instance().apply_lost_connect(socket, "客户端关闭".to_string());
    }

    fn kick_callback(
        ev: &mut EventLoop,
        _timer: u32,
        data: Option<&mut CellAny>,
    ) -> (RetValue, u64) {
        let sock_ev = any_to_mut!(data.unwrap(), SocketEvent);
        let _ = ev.unregister_socket(sock_ev.as_raw_socket());
        LuaEngine::instance().apply_lost_connect(sock_ev.as_raw_socket(), "逻辑层主动退出".to_string());
        if sock_ev.is_websocket() {
            WebsocketMyMgr::instance().remove_socket(sock_ev.as_raw_socket());
        }
        (RetValue::OVER, 0)
    }

    fn lua_exec_callback(
        _ev: &mut EventLoop,
        _timer: u32,
        _data: Option<&mut CellAny>,
    ) -> (RetValue, u64) {
        LuaEngine::instance().execute_lua();
        (RetValue::OK, 0)
    }

    pub fn add_lua_excute(&mut self) {
        self.lua_exec_id = self.event_loop
                               .add_timer(EventEntry::new_timer(1,
                                                                true,
                                                                Some(Self::lua_exec_callback),
                                                                None));
    }

    pub fn run_timer(&mut self) {
        
    }
}
