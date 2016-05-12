use std::collections::HashMap;
use std::net::TcpStream;
use std::io::prelude::*;
use std::mem;
use std::boxed::Box;

use SocketEvent;
use LuaEngine;
use NetMsg;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use td_rp::{self, Buffer, decode_number};
use td_revent::*;

static mut el: *mut EventMgr = 0 as *mut _;
static mut read_data: [u8; 65536] = [0; 65536];
pub struct EventMgr {
    connect_ids: HashMap<i32, SocketEvent>,
    mutex: Arc<ReentrantMutex<i32>>,
    event_loop: EventLoop,
    lua_exec_id: u32,
}

impl EventMgr {
    pub fn new() -> EventMgr {
        EventMgr {
            connect_ids: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0)),
            event_loop: EventLoop::new().ok().unwrap(),
            lua_exec_id: 0,
        }
    }

    pub fn instance() -> &'static mut EventMgr {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(EventMgr::new()));
            }
            &mut *el
        }
    }

    pub fn get_event_loop(&mut self) -> &mut EventLoop {
        &mut self.event_loop
    }

    pub fn new_socket_event(&mut self, ev: SocketEvent) -> bool {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        LuaEngine::instance().apply_new_connect(ev.get_cookie(),
                                                ev.get_socket_fd(),
                                                ev.get_client_ip(),
                                                ev.get_server_port());
        self.connect_ids.insert(ev.get_socket_fd(), ev);
        true
    }

    pub fn kick_socket(&mut self, sock: i32) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        let sock_ev = self.connect_ids.remove(&sock);
        if sock_ev.is_some() {
            drop(TcpStream::from_fd(sock_ev.unwrap().get_socket_fd()));
        }
        self.event_loop.del_event(sock as u32, EventFlags::all());
    }

    pub fn write_callback(_ev: &mut EventLoop, fd: u32, _: EventFlags, _: *mut ()) -> i32 {
        let fd = fd as i32;
        let socket_event = unwrap_or!(EventMgr::instance().get_socket_event(fd), return 0);
        if socket_event.get_out_cache().len() == 0 {
            return 0;
        }
        let mut tcp = TcpStream::from_fd(fd);
        let write_ret;
        loop {
            write_ret = tcp.write(socket_event.get_out_cache().get_data());
            if write_ret.is_err() {
                break;
            }
            let size = write_ret.as_ref().map(|ref e| *e.clone()).unwrap();
            if size != socket_event.get_out_cache().len() {
                if size > 0 {
                    socket_event.get_out_cache().drain(size);    
                }
                break;
            }
            socket_event.get_out_cache().clear();
            break;
        }

        mem::forget(tcp);

        if write_ret.is_err() {
            EventMgr::instance().add_kick_event(fd);
            return 0;
        }

        0
    }

    // pub fn send_netmsg(&mut self, fd: i32, net_msg: &mut NetMsg) -> bool {
    //     println!("send_netmsg {:?}", fd);
    //     let _ = net_msg.read_head();
    //     if net_msg.get_pack_len() != net_msg.len() as u32 {
    //         println!("error!!!!!!!! net_msg.get_pack_len() = {:?}, net_msg.len() = {:?}", net_msg.get_pack_len(), net_msg.len());
    //         return false;
    //     }
    //     let mutex = self.mutex.clone();
    //     let _guard = mutex.lock().unwrap();
    //     if !self.connect_ids.contains_key(&fd) {
    //         println!("send_netmsg but connect_ids no exist ==== {:?}", fd);
    //         return false;
    //     }

    //     let socket_event = self.connect_ids.get_mut(&fd).unwrap();
    //     let _ = socket_event.get_out_cache().write(net_msg.get_buffer().get_data());
    //     //判断缓冲区大小
    //     true
    // }

    pub fn send_netmsg(&mut self, fd: i32, net_msg: &mut NetMsg) -> bool {
        let _ = net_msg.read_head();
        if net_msg.get_pack_len() != net_msg.len() as u32 {
            println!("error!!!!!!!! net_msg.get_pack_len() = {:?}, net_msg.len() = {:?}", net_msg.get_pack_len(), net_msg.len());
            return false;
        }
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }
        let mut tcp = TcpStream::from_fd(fd);
        let mut write_ret;
        let mut success = false;
        loop {
            let socket_event = self.connect_ids.get_mut(&fd).unwrap();
            if socket_event.get_out_cache().len() > 0 {
                write_ret = tcp.write(socket_event.get_out_cache().get_data());
                if write_ret.is_err() {
                    break;
                }
                let size = write_ret.as_ref().map(|ref e| *e.clone()).unwrap();
                if size != socket_event.get_out_cache().len() {
                    if size > 0 {
                        socket_event.get_out_cache().drain(size);    
                    }
                    let _ = socket_event.get_out_cache().write(net_msg.get_buffer().get_data());
                    break;
                }
                socket_event.get_out_cache().clear();
            }
            write_ret = tcp.write(net_msg.get_buffer().get_data());
            if write_ret.is_err() {
                break;
            }

            let size = write_ret.as_ref().map(|ref e| *e.clone()).unwrap();
            if size != net_msg.get_buffer().len() {
                if size > 0 {
                    net_msg.get_buffer().drain(size);    
                }
                let _ = socket_event.get_out_cache().write(net_msg.get_buffer().get_data());
                break;
            }

            success = true;
            break;
        }

        mem::forget(tcp);
        if write_ret.is_err() {
            self.add_kick_event(fd);
            return success;
        }

        //TODO if success = false, we may need add write event
        success
    }

    pub fn get_socket_event(&mut self, fd: i32) -> Option<&mut SocketEvent> {
    let _guard = self.mutex.lock().unwrap();
        self.connect_ids.get_mut(&fd)
    }

    pub fn data_recieved(&mut self, fd: i32, data: &[u8]) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = EventMgr::instance().get_socket_event(fd as i32);
        if socket_event.is_none() {
            return;
        }
        let mut socket_event = socket_event.unwrap();
        let _ = socket_event.get_buffer().write(data);
        self.try_dispatch_message(fd);
    }

    pub fn try_dispatch_message(&mut self, fd: i32) {
        let mutex = self.mutex.clone();
        let _guard = mutex.lock().unwrap();

        let socket_event = EventMgr::instance().get_socket_event(fd as i32);
        if socket_event.is_none() {
            return;
        }
        let mut socket_event = socket_event.unwrap();
        let buffer_len = socket_event.get_buffer().len();
        let buffer = socket_event.get_buffer();
        loop {
            let message: Option<Vec<u8>> = EventMgr::get_next_message(buffer);
            if message.is_none() {
                break;
            }
            let msg = NetMsg::new_by_data(&message.unwrap()[..]);
            if msg.is_err() {
                println!("message error kick fd {:?} msg = {:?}, buffer = {}", fd, msg.err(), buffer_len);
                self.add_kick_event(fd);
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
        let mut length: u32 = unwrap_or!(decode_number(buffer, td_rp::TYPE_U32).ok(), return None)
                              .into();
        buffer.set_rpos(rpos);
        length = unsafe { ::std::cmp::min(length, read_data.len() as u32) };
        if buffer.len() - rpos < length as usize {
            return None;
        }
        Some(buffer.drain_collect(length as usize))
    }

    pub fn exist_socket_event(&self, fd: i32) -> bool {
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

    pub fn add_kick_event(&mut self, fd: i32) {
        let _guard = self.mutex.lock().unwrap();
        let sock_ev = unwrap_or!(self.connect_ids.remove(&fd), return);
        self.event_loop.del_event(sock_ev.get_socket_fd() as u32, EventFlags::all());
        self.event_loop
            .add_timer(EventEntry::new_timer(200000,
                                             false,
                                             Some(EventMgr::kick_callback),
                                             Some(Box::into_raw(Box::new(sock_ev)) as *mut ())));
    }

    fn kick_callback(_: &mut EventLoop, _: u32, _: EventFlags, data: *mut ()) -> i32 {
        let sock_ev = unsafe { Box::from_raw(data as *mut SocketEvent) };
        LuaEngine::instance().apply_lost_connect(sock_ev.get_socket_fd());
        drop(TcpStream::from_fd(sock_ev.get_socket_fd()));
        0
    }

    fn lua_exec_callback(_: &mut EventLoop, _: u32, _: EventFlags, _: *mut ()) -> i32 {
        LuaEngine::instance().execute_lua();
        0
    }

    pub fn add_lua_excute(&mut self) {
        self.lua_exec_id = self.event_loop
                               .add_timer(EventEntry::new_timer(100,
                                                                true,
                                                                Some(EventMgr::lua_exec_callback),
                                                                None));
    }
}
