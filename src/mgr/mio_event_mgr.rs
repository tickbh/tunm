use std::collections::HashMap;
use std::io::prelude::*;
use std::boxed::Box;
use std::any::Any;
use std::io::{self, Read, Write};
use std::str::from_utf8;

use std::io::Result;

use SocketEvent;
use LuaEngine;
use NetMsg;
use WebSocketMgr;
use WebsocketMyMgr;
use LogUtils;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use tunm_proto::{self, Buffer, decode_number};

use crate::net::AsSocket;

use mio::event::Event;
use mio::net::{TcpListener, TcpStream};
use mio::{Events, Interest, Poll, Registry, Token};

static mut EL: *mut MioEventMgr = 0 as *mut _;
static mut READ_DATA: [u8; 65536] = [0; 65536];
pub struct MioEventMgr {
    connect_ids: HashMap<Token, SocketEvent>,
    
    mutex: Arc<ReentrantMutex<i32>>,
    poll: Poll,
    lua_exec_id: u32,
    exit: bool,
}

impl MioEventMgr {
    pub fn new() -> MioEventMgr {
        MioEventMgr {
            connect_ids: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0)),
            poll: Poll::new().ok().unwrap(),
            lua_exec_id: 0,
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
        // self.event_loop.shutdown();
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
        self.connect_ids.insert(Token(ev.as_raw_socket() as usize) , ev);
        true
    }
    
    pub fn new_socket_server(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.as_raw_socket(),
                                                ev.get_client_ip(),
                                                ev.get_server_port(),
                                                ev.is_websocket());
        self.connect_ids.insert(Token(ev.as_raw_socket() as usize) , ev);
        true
    }
    
    pub fn new_socket_client(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.as_raw_socket(),
                                                ev.get_client_ip(),
                                                ev.get_server_port(),
                                                ev.is_websocket());
        self.connect_ids.insert(Token(ev.as_raw_socket() as usize) , ev);
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

    pub fn write_data(&mut self, fd: Token, data: &[u8]) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }
        return true;
        // let event_loop = MioEventMgr::instance().get_event_loop();
        // match event_loop.send_socket(&fd, data) {
        //     Ok(_len) => return true,
        //     Err(_) => return false,
        // }
    }

    pub fn send_netmsg(&mut self, fd: Token, net_msg: &mut NetMsg) -> bool {
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

        return true;

        // if is_websocket {
        //     if is_mio {
        //         return WebSocketMgr::instance().send_message(fd as i32, net_msg);
        //     } else {
        //         return WebsocketMyMgr::instance().send_message(fd, net_msg);
        //     }
        // } else {
        //     let data = net_msg.get_buffer().get_data();
        //     self.write_data(fd, data)
        // }
    }

    pub fn close_fd(&mut self, fd: Token, reason: String) -> bool {
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

        // if is_websocket {
        //     if is_mio {
        //         return WebSocketMgr::instance().close_fd(fd as i32);
        //     } else {
        //         return WebsocketMyMgr::instance().close_fd(fd);
        //     }
        // } else {
        //     self.add_kick_event(fd, reason);
        // }
        true
    }

    pub fn get_socket_event(&mut self, fd: Token) -> Option<&mut SocketEvent> {
    let _guard = self.mutex.lock().unwrap();
        self.connect_ids.get_mut(&fd)
    }

    pub fn data_recieved(&mut self, fd: Token, data: &[u8]) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = MioEventMgr::instance().get_socket_event(fd);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let _ = socket_event.get_buffer().write(data);
        self.try_dispatch_message(fd);
    }

    pub fn try_dispatch_message(&mut self, fd: Token) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = MioEventMgr::instance().get_socket_event(fd);
        if socket_event.is_none() {
            return;
        }
        let socket_event = socket_event.unwrap();
        let buffer_len = socket_event.get_buffer().len();
        let buffer = socket_event.get_buffer();
        loop {
            let message: Option<Vec<u8>> = MioEventMgr::get_next_message(buffer);
            if message.is_none() {
                break;
            }
            let msg = NetMsg::new_by_data(&message.unwrap()[..]);
            if msg.is_err() {
                println!("message error kick fd {:?} msg = {:?}, buffer = {}", fd, msg.err(), buffer_len);
                self.add_kick_event(fd, "Message Dispatch Error".to_string());
                break;
            }

            // LuaEngine::instance().apply_message(fd, msg.ok().unwrap());
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

    pub fn exist_socket_event(&self, fd: Token) -> bool {
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

    pub fn remove_connection(&mut self, fd:Token) {
        let _guard = self.mutex.lock().unwrap();
        let _sock_ev = unwrap_or!(self.connect_ids.remove(&fd), return);
    }

    pub fn add_kick_event(&mut self, fd: Token, reason: String) {
        // println!("add kick event fd = {} reason = {}", fd, reason);
        // let websocket_fd = {
        //     let _guard = self.mutex.lock().unwrap();
        //     let info = format!("Close Fd {} by Reason {}", fd, reason);
        //     println!("{}", info);
        //     LogUtils::instance().append(2, &*info);

        //     let sock_ev = unwrap_or!(self.connect_ids.remove(&fd), return);
        //     if !sock_ev.is_websocket() || !sock_ev.is_mio() {
        //         // self.event_loop.unregister_socket(sock_ev.as_raw_socket(), EventFlags::all());
        //         self.event_loop
        //             .add_timer(EventEntry::new_timer(20,
        //                                              false,
        //                                              Some(Self::kick_callback),
        //                                              Some(Box::new(sock_ev))));
        //         return;
        //     }
        //     sock_ev.get_socket_fd()
        // };

        // LuaEngine::instance().apply_lost_connect(websocket_fd as Token, "服务端关闭".to_string());
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

    // pub fn add_lua_excute(&mut self) {
    //     self.lua_exec_id = self.event_loop
    //                            .add_timer(EventEntry::new_timer(1,
    //                                                             true,
    //                                                             Some(Self::lua_exec_callback),
    //                                                             None));
    // }

    pub fn run_server(&mut self) -> Result<()> {

        let mut events = Events::with_capacity(128);
        loop {
            self.poll.poll(&mut events, None)?;
    
            for event in events.iter() {
                let token = event.token();
                if let Some(socket_event) = self.connect_ids.get_mut(&token) {
                    if socket_event.is_server() {
                        if let Some(mut server) = socket_event.as_server() {
                            let (mut connection, address) = match server.accept() {
                                Ok((connection, address)) => (connection, address),
                                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                                    // If we get a `WouldBlock` error we know our
                                    // listener has no more incoming connections queued,
                                    // so we can return to polling and wait for some
                                    // more.
                                    break;
                                }
                                Err(e) => {
                                    // If it was any other kind of error, something went
                                    // wrong and we terminate with an error.
                                    return Err(e);
                                }
                            };
                            println!("Accepted connection from: {}", address);
                            let token = Token(connection.as_socket());
                            self.poll.registry().register(
                                &mut connection,
                                token,
                                Interest::READABLE.add(Interest::WRITABLE),
                            )?;
                            let ev = SocketEvent::new_client(connection, socket_event.get_server_port());
                            self.new_socket_client(ev);
                            // self.client_tcp.insert(token, connection);
                        };
                        
                    } else {
                        if let Some(mut client) = socket_event.as_client() {
                            if event.is_writable() {
                                // We can (maybe) write to the connection.
                                // client.get_out_cache().get_write_data()
                                match client.write(&[]) {
                                    // We want to write the entire `DATA` buffer in a single go. If we
                                    // write less we'll return a short write error (same as
                                    // `io::Write::write_all` does).
                                    // Ok(n) if n < DATA.len() => return Err(io::ErrorKind::WriteZero.into()),
                                    Ok(_) => {
                                        // After we've written something we'll reregister the connection
                                        // to only respond to readable events.
                                        self.poll.registry().reregister(client, token, Interest::READABLE)?
                                    }
                                    // Would block "errors" are the OS's way of saying that the
                                    // connection is not actually ready to perform this I/O operation.
                                    Err(ref err) if Self::would_block(err) => {}
                                    // Got interrupted (how rude!), we'll try again.
                                    // Err(ref err) if Self::interrupted(err) => {
                                    //     return handle_connection_event(registry, connection, event)
                                    // }
                                    // Other errors we'll consider fatal.
                                    Err(err) => return Err(err),
                                }
                            }
                        
                            if event.is_readable() {
                                let mut connection_closed = false;
                                let mut received_data = vec![0; 4096];
                                let mut bytes_read = 0;
                                // We can (maybe) read from the connection.
                                loop {
                                    match client.read(&mut received_data[bytes_read..]) {
                                        Ok(0) => {
                                            // Reading 0 bytes means the other side has closed the
                                            // connection or is done writing, then so are we.
                                            connection_closed = true;
                                            break;
                                        }
                                        Ok(n) => {
                                            bytes_read += n;
                                            if bytes_read == received_data.len() {
                                                received_data.resize(received_data.len() + 1024, 0);
                                            }
                                        }
                                        // Would block "errors" are the OS's way of saying that the
                                        // connection is not actually ready to perform this I/O operation.
                                        Err(ref err) if err.kind() == io::ErrorKind::WouldBlock => break,
                                        Err(ref err) if err.kind() == io::ErrorKind::Interrupted => continue,
                                        // Other errors we'll consider fatal.
                                        Err(err) => return Err(err),
                                    }
                                }
                        
                                if bytes_read != 0 {
                                    let received_data = &received_data[..bytes_read];
                                    if let Ok(str_buf) = from_utf8(received_data) {
                                        println!("Received data: {}", str_buf.trim_end());
                                    } else {
                                        println!("Received (none UTF-8) data: {:?}", received_data);
                                    }
                                }
                        
                                if connection_closed {
                                    println!("Connection closed");
                                    return Ok(());
                                }
                            }
                        };
                    }
                }

                // match event.token() {
                //     SERVER => loop {
                //         // Received an event for the TCP server socket, which
                //         // indicates we can accept an connection.
                //         let (mut connection, address) = match server.accept() {
                //             Ok((connection, address)) => (connection, address),
                //             Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                //                 // If we get a `WouldBlock` error we know our
                //                 // listener has no more incoming connections queued,
                //                 // so we can return to polling and wait for some
                //                 // more.
                //                 break;
                //             }
                //             Err(e) => {
                //                 // If it was any other kind of error, something went
                //                 // wrong and we terminate with an error.
                //                 return Err(e);
                //             }
                //         };
    
                //         println!("Accepted connection from: {}", address);
    
                //         let token = next(&mut unique_token);
                //         poll.registry().register(
                //             &mut connection,
                //             token,
                //             Interest::READABLE.add(Interest::WRITABLE),
                //         )?;
    
                //         connections.insert(token, connection);
                //     },
                //     token => {
                //         // Maybe received an event for a TCP connection.
                //         let done = if let Some(connection) = connections.get_mut(&token) {
                //             handle_connection_event(poll.registry(), connection, event)?
                //         } else {
                //             // Sporadic events happen, we can safely ignore them.
                //             false
                //         };
                //         if done {
                //             if let Some(mut connection) = connections.remove(&token) {
                //                 poll.registry().deregister(&mut connection)?;
                //             }
                //         }
                //     }
                // }
            }
        }
        Ok(())
    }

    
    fn would_block(err: &io::Error) -> bool {
        err.kind() == io::ErrorKind::WouldBlock
    }

    fn interrupted(err: &io::Error) -> bool {
        err.kind() == io::ErrorKind::Interrupted
    }

}
