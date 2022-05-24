use std::collections::HashMap;
use std::boxed::Box;
use std::io::{self, Write};

use std::io::Result;

use tunm_timer::{Factory, RetTimer, Timer, Handler};

use crate::{LogUtils};
use SocketEvent;
use LuaEngine;
use NetMsg;
use WebSocketMgr;
use DbPool;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use tunm_proto::{self, Buffer, decode_number};

use crate::net::{AsSocket, AcceptCb, ReadCb, EndCb};

use mio::net::{TcpListener};
use mio::{Events, Interest, Poll, Token};

static mut EL: *mut MioEventMgr = 0 as *mut _;
static mut READ_DATA: [u8; 65536] = [0; 65536];
pub struct MioEventMgr {
    connect_ids: HashMap<String, SocketEvent>,
    
    mutex: Arc<ReentrantMutex<i32>>,
    timer: Timer<TimeHandle>,
    poll: Poll,
    exit: bool,
}


pub struct TimeHandle {
    timer_name: String,
    unique: String,
}

impl TimeHandle {
    pub fn new(timer_name: String) -> TimeHandle {
        TimeHandle {
            timer_name,
            unique: String::new(),
        }
    }
    
    #[allow(unused)]
    pub fn new_unique(timer_name: String, unique: String) -> TimeHandle {
        TimeHandle {
            timer_name,
            unique,
        }
    }

}

impl Factory for TimeHandle {
    fn on_trigger(&mut self, _timer: &mut Timer<Self>, id: u64) -> RetTimer {
        match &*self.timer_name {
            "MIO" => {
                let _ = MioEventMgr::instance().run_one_server();
            }
            "lua_set" => {
                LuaEngine::instance().apply_args_func("timer_event_dispatch".to_string(), vec![id.to_string()]);
            }
            "LUA_EXEC" => {
                LuaEngine::instance().execute_lua();
            }
            "CHECK_DB" => {
                DbPool::instance().check_connect_timeout();
            }
            "KICK_SOCKET" => {
                LuaEngine::instance().apply_lost_connect(&self.unique, "定时关闭".to_string());
            }
            _ => {
                println!("unknow name {}", self.timer_name);
            }
        }
        RetTimer::Ok
    }
}


impl MioEventMgr {
    pub fn new() -> MioEventMgr {
        MioEventMgr {
            connect_ids: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0)),
            poll: Poll::new().ok().unwrap(),
            timer: Timer::new(100),
            exit: false,
        }
    }

    pub fn instance() -> &'static mut MioEventMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(MioEventMgr::new()));
            }
            &mut *EL
        }
    }

    // #[cfg(unix)]
    // pub fn as_socket(tcp: &TcpStream) -> usize {
    //     return tcp.as_raw_fd() as usize;
    // }
    
    // #[cfg(windows)]
    // pub fn as_socket(tcp: &TcpStream) -> usize {
    //     return tcp.as_raw_socket() as usize;
    // }

    pub fn get_poll(&mut self) -> &mut Poll {
        &mut self.poll
    }

    pub fn shutdown_event(&mut self) {
        self.exit = true;
        self.timer.set_shutdown(true);
        // self.event_loop.shutdown();
    }

    pub fn is_exit(&self) -> bool {
        self.exit
    }

    pub fn new_socket_event_lua(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.get_unique().clone(),
                                                ev.get_client_ip(),
                                                ev.get_server_port(),
                                                ev.is_websocket());
        self.connect_ids.insert(ev.get_unique().clone(), ev);
        true
    }
    
    pub fn new_socket_server(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        self.connect_ids.insert(ev.get_unique().clone(), ev);
        true
    }
    
    pub fn new_socket_client(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        self.connect_ids.insert(ev.get_unique().clone() , ev);
        true
    }

    
    pub fn new_socket_local(&mut self, mut ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        if ev.is_client() {
            let token = ev.as_token();
            let _ = self.poll.registry().register(ev.as_client().unwrap(), token, Interest::READABLE);
        }

        if ev.read.is_none() {
            ev.set_read(Some(Self::read_callback));
        }
        if ev.end.is_none() {
            ev.set_end(Some(Self::read_end_callback));
        }
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.get_unique().clone(),
                                                ev.get_client_ip(),
                                                ev.get_server_port(),
                                                ev.is_websocket());
        self.connect_ids.insert(ev.get_unique().clone() , ev);
        true
    }


    // pub fn receive_socket_event(&mut self, ev: SocketEvent) -> bool {
    //     let mutex = self.mutex.clone();
    //     let _guard = mutex.lock().unwrap();
    //     self.connect_ids.insert(ev.as_raw_socket(), ev);
    //     true
    // }

    // pub fn kick_socket(&mut self, sock: Token) {
    //     let mutex = self.mutex.clone();
    //     let _guard = mutex.lock().unwrap();
    //     let _sock_ev = self.connect_ids.remove(&sock);
    //     let _ = self.event_loop.unregister_socket(sock);
    // }

    pub fn send_netmsg(&mut self, unique: &String, net_msg: &mut NetMsg) -> bool {
        let _ = net_msg.read_head();
        if net_msg.get_pack_len() != net_msg.len() as u32 {
            println!("error!!!!!!!! net_msg.get_pack_len() = {:?}, net_msg.len() = {:?}", net_msg.get_pack_len(), net_msg.len());
            return false;
        }
        let is_websocket = {
            let mutex = self.mutex.clone();
            let _guard = mutex.lock().unwrap();
            if !self.connect_ids.contains_key(unique) {
                return false;
            } else {
                let socket_event = self.connect_ids.get_mut(unique).unwrap();
                socket_event.is_websocket()
            }
        };
        
        if is_websocket {
            return WebSocketMgr::instance().send_message(unique, net_msg);
        } else {
            net_msg.get_buffer().set_rpos(0);
            return self.write_to_socket(unique, &net_msg.get_buffer().get_write_data()[..]).ok().unwrap_or(false);
        }

    }

    pub fn close_fd(&mut self, unique: &String, reason: String) -> bool {
        let (is_websocket, unique) = {
            let mutex = self.mutex.clone();
            let _guard = mutex.lock().unwrap();
            if !self.connect_ids.contains_key(unique) {
                return false;
            } else {
                let socket_event = self.connect_ids.get_mut(unique).unwrap();
                (socket_event.is_websocket(), socket_event.get_unique().clone())
            }
        };

        if let Some(mut socket_event) = self.connect_ids.remove(&unique) {
            if socket_event.is_server() {
                let _ = self.poll.registry().deregister(socket_event.as_server().unwrap());
            } else if socket_event.is_client() {
                let _ = self.poll.registry().deregister(socket_event.as_client().unwrap());
            }
        }

        if is_websocket {
            return WebSocketMgr::instance().close_fd(&unique);
        } else {
            LuaEngine::instance().apply_lost_connect(&unique, reason);
        }
        true
    }

    pub fn get_socket_event(&mut self, unique: &String) -> Option<&mut SocketEvent> {
    let _guard = self.mutex.lock().unwrap();
        self.connect_ids.get_mut(unique)
    }

    pub fn data_recieved(&mut self, unique: &String, data: &[u8]) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = MioEventMgr::instance().get_socket_event(unique);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let _ = socket_event.get_in_buffer().write(data);
        self.try_dispatch_message(unique);
    }

    pub fn try_dispatch_message(&mut self, unique: &String) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = MioEventMgr::instance().get_socket_event(unique);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let buffer_len = socket_event.get_in_buffer().data_len();
        let buffer = socket_event.get_in_buffer();
        loop {
            let message: Option<Vec<u8>> = MioEventMgr::get_next_message(buffer);
            if message.is_none() {
                break;
            }
            let msg = NetMsg::new_by_data(&message.unwrap()[..]);
            if msg.is_err() {
                println!("message error kick fd {:?} msg = {:?}, buffer = {}", unique, msg.err(), buffer_len);
                self.add_kick_event(unique, "Message Dispatch Error".to_string());
                break;
            }

            LuaEngine::instance().apply_message(unique, msg.ok().unwrap());
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

    pub fn exist_socket_event(&self, unique: &String) -> bool {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.contains_key(unique)
    }

    pub fn all_socket_size(&self) -> usize {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.len()
    }

    pub fn kick_all_socket(&self) {
        let _guard = self.mutex.lock().unwrap();
        self.connect_ids.len();
    }

    pub fn remove_connection(&mut self, unique: String) {
        let _guard = self.mutex.lock().unwrap();
        let _sock_ev = unwrap_or!(self.connect_ids.remove(&unique), return);
    }

    pub fn add_kick_event(&mut self, unique: &String, reason: String) {
        let _guard = self.mutex.lock().unwrap();
        let info = format!("Close Fd {} by Reason {}", unique, reason);
        println!("{}", info);
        LogUtils::instance().append(2, &*info);

        let sock_ev = unwrap_or!(self.connect_ids.remove(unique), return);
        if !sock_ev.is_websocket() || !sock_ev.is_mio() {
            let _ = self.timer.add_timer(Handler::new_step_ms(
                TimeHandle::new_unique("KICK_SOCKET".to_string(), unique.clone()), 20, false, false
            ));
            return;
        }

        LuaEngine::instance().apply_lost_connect(&unique, "服务端关闭".to_string());
    }

    // //由事件管理主动推送关闭的调用
    // pub fn notify_connect_lost(&mut self, socket: Token) {
    //     let _sock_ev = unwrap_or!(self.connect_ids.remove(&socket), return);
    //     LuaEngine::instance().apply_lost_connect(socket, "客户端关闭".to_string());
    // }

    // fn kick_callback(
    //     ev: &mut EventLoop,
    //     _timer: u32,
    //     data: Option<&mut CellAny>,
    // ) -> (RetValue, u64) {
    //     let sock_ev = any_to_mut!(data.unwrap(), SocketEvent);
    //     let _ = ev.unregister_socket(sock_ev.as_raw_socket());
    //     LuaEngine::instance().apply_lost_connect(sock_ev.as_raw_socket(), "逻辑层主动退出".to_string());
    //     if sock_ev.is_websocket() {
    //         WebsocketMyMgr::instance().remove_socket(sock_ev.as_raw_socket());
    //     }
    //     (RetValue::OVER, 0)
    // }

    // fn lua_exec_callback(
    //     _ev: &mut EventLoop,
    //     _timer: u32,
    //     _data: Option<&mut CellAny>,
    // ) -> (RetValue, u64) {
    //     LuaEngine::instance().execute_lua();
    //     (RetValue::OK, 0)
    // }

    pub fn add_lua_excute(&mut self) {
        let _ = self.add_timer_step("LUA_EXEC".to_string(), 1, true, false);
    }

    pub fn write_to_socket(&mut self, unique: &String, bytes: &[u8]) -> Result<bool> {
        if let Some(socket_event) = self.connect_ids.get_mut(unique) {
            if socket_event.is_client() {
                // let size = socket_event.get_out_buffer().write(bytes)?;
                // let token = socket_event.as_token();
                // self.poll.registry().reregister(socket_event.as_client().unwrap(), token, Interest::READABLE.add(Interest::WRITABLE))?;
                // Ok(size == bytes.len())
                let _ = socket_event.get_out_buffer().write(bytes)?;
                socket_event.write_data()
            } else {
                Ok(false)
            }
        } else {
            Ok(false)
        }
    }

    
    pub fn write_by_socket_event(&mut self, ev: &mut SocketEvent, bytes: &[u8]) -> Result<bool> {
        if ev.is_client() {
            let _ = ev.get_out_buffer().write(bytes)?;
            let all = ev.write_data()?;
            Ok(all)
        } else {
            Ok(false)
        }
    }

    
    fn read_callback(
        socket: &mut SocketEvent,
    ) -> usize {
        MioEventMgr::instance().try_dispatch_message(socket.get_unique());
        0
    }

    fn read_end_callback(
        socket: &mut SocketEvent) {
        LuaEngine::instance().apply_lost_connect(&socket.get_unique(), "客户端关闭".to_string());
    }

    fn accept_callback(
        _socket: &mut SocketEvent,
    ) -> usize {
        return 0;
    }


    pub fn listen_server(&mut self, bind_ip: String, bind_port: u16, accept: Option<AcceptCb>, read: Option<ReadCb>, end: Option<EndCb>)-> Result<usize>  {

        let bind_addr = if bind_port == 0 {
            unwrap_or!(format!("{}", bind_ip.trim_matches('\"')).parse().ok(), return Ok(0))
        } else {
            unwrap_or!(format!("{}:{}", bind_ip.trim_matches('\"'), bind_port).parse().ok(), return Ok(0))
        };
        let mut listener = TcpListener::bind(bind_addr).unwrap();
        let socket = listener.as_socket();
        self.poll.registry().register(&mut listener, Token(socket), Interest::READABLE)?;
        let mut ev = SocketEvent::new_server(listener, bind_port);
        if accept.is_some() {
            ev.set_accept(accept);
        } else {
            ev.set_accept(Some(Self::accept_callback));
        }
        if read.is_some() {
            ev.set_read(read);
        } else {
            ev.set_read(Some(Self::read_callback));
        }
        if end.is_some() {
            ev.set_end(end);
        } else {
            ev.set_end(Some(Self::read_end_callback));
        }
        self.new_socket_server(ev);
        Ok(socket)
    }

    pub fn is_unique_server(&self, unique: &String) -> bool {
        if let Some(socket_event) = self.connect_ids.get(unique) {
            return socket_event.is_server()
        } else {
            false
        }
    }

    pub fn is_unique_client(&self, unique: &String) -> bool {
        if let Some(socket_event) = self.connect_ids.get(unique) {
            return socket_event.is_client()
        } else {
            false
        }
    }

    pub fn run_one_server(&mut self) -> Result<()> {

        let mut events = Events::with_capacity(128);
        self.poll.poll(&mut events, None)?;
        for event in events.iter() {
            let mut is_need_cose = false;
            let unique = SocketEvent::token_to_unique(&event.token()) ;
            if self.is_unique_server(&unique) {
                loop {
                    let socket_event = self.connect_ids.get_mut(&unique).unwrap();
                    let (mut connection, address) = {
                            match socket_event.as_server().unwrap().accept() {
                            Ok((connection, address)) => (connection, address),
                            Err(ref err) if Self::would_block(err) => {
                                // If we get a `WouldBlock` error we know our
                                // listener has no more incoming connections queued,
                                // so we can return to polling and wait for some
                                // more.
                                break;
                            }
                            Err(ref err) if Self::interrupted(err) => {
                                continue;
                            }
                            Err(e) => {
                                println!("error ==== {:?}", e);
                                // If it was any other kind of error, something went
                                // wrong and we terminate with an error.
                                return Err(e);
                            }
                        }
                    };
                    
                    println!("Accepted connection from: {}", address);
                    let client_token = Token(connection.as_socket());
                    self.poll.registry().register(
                        &mut connection,
                        client_token,
                        Interest::READABLE,
                    )?;
                    let mut ev = SocketEvent::new_client(connection, socket_event.get_server_port());
                    if socket_event.read.is_some() {
                        ev.set_read(socket_event.read);
                    }
                    if socket_event.end.is_some() {
                        ev.set_end(socket_event.end);
                    }
                    if socket_event.call_accept(&mut ev) != 1 {
                        self.new_socket_event_lua(ev);
                    } else {
                        self.new_socket_client(ev);
                    }
                }
            } else if self.is_unique_client(&unique) {
                let socket_event = self.connect_ids.get_mut(&unique).unwrap();
                let mut is_read_data = false;
                // if event.is_writable() {
                //     // We can (maybe) write to the connection.
                //     // client.get_out_cache().get_write_data()
                //     loop {
                //         match socket_event.write_data() {
                //             // We want to write the entire `DATA` buffer in a single go. If we
                //             // write less we'll return a short write error (same as
                //             // `io::Write::write_all` does).
                //             // Ok(n) if n < DATA.len() => return Err(io::ErrorKind::WriteZero.into()),
                //             Ok(true) => {
                //                 // After we've written something we'll reregister the connection
                //                 // to only respond to readable events.
                //                 self.poll.registry().reregister(socket_event.as_client().unwrap(), event.token(), Interest::READABLE)?;
                //             }
                //             Ok(false) => {
                //             }
                //             // Would block "errors" are the OS's way of saying that the
                //             // connection is not actually ready to perform this I/O operation.
                //             Err(ref err) if Self::would_block(err) => {
                //                 break;
                //             }
                //             // Got interrupted (how rude!), we'll try again.
                //             Err(ref err) if Self::interrupted(err) => {
    
                //             }
                //             // Other errors we'll consider fatal.
                //             Err(err) => {
                //                 is_need_cose = true;
                //                 break;
                //             },
                //         }
                //     }
                // }
            
                if event.is_readable() {
                    loop {
                        match socket_event.read_data() {
                            Ok(true) => {
                                // Reading 0 bytes means the other side has closed the
                                // connection or is done writing, then so are we.
                                is_need_cose = true;
                                break;
                            }
                            Ok(false) => {
                                is_read_data = true;
                                break;
                            }
                            Err(_err) => {
                                is_need_cose = true;
                                break;
                            },
                        }
                    }

                    if is_read_data {
                        socket_event.call_read();
                    }
                }
            }
            if is_need_cose {
                if let Some(mut socket_event) = self.connect_ids.remove(&unique) {
                    socket_event.call_end();

                    if socket_event.is_server() {
                        self.poll.registry().deregister(socket_event.as_server().unwrap())?;
                    } else if socket_event.is_client() {
                        self.poll.registry().deregister(socket_event.as_client().unwrap())?;

                    }
                }
            }
        }
        Ok(())
    }

    pub fn run_server(&mut self) -> Result<()> {
        loop {
            if self.exit {
                return Ok(());
            }
            self.run_one_server()?;
        }
    }


    pub fn delete_timer(&mut self, time_id: u64) {
        let _ = self.timer.del_timer(time_id);
    }

    pub fn add_timer_step(&mut self, timer_name: String, tick_step: u64, is_repeat: bool, at_once: bool) -> u64 {
        self.timer.add_timer(Handler::new_step_ms(
            TimeHandle::new(timer_name), tick_step, is_repeat, at_once
        ))
    }

    pub fn add_server_to_timer(&mut self) {
        self.timer.add_timer(Handler::new_step(
            TimeHandle::new("MIO".to_string()), 10, true, false));
    }
    
    pub fn add_check_db_timer(&mut self) {
        self.timer.add_timer(Handler::new_step_ms(
            TimeHandle::new("CHECK_DB".to_string()), 5 * 60 * 1000, true, false));
    }


    pub fn run_timer(&mut self) {
        // self.add_server_to_timer();
        self.timer.run_loop_timer();
    }

    
    fn would_block(err: &io::Error) -> bool {
        err.kind() == io::ErrorKind::WouldBlock
    }

    fn interrupted(err: &io::Error) -> bool {
        err.kind() == io::ErrorKind::Interrupted
    }

}
