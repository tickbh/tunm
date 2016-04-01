use std::collections::{HashSet};
use std::net::{TcpListener, TcpStream};
use std::mem;
use std::io::{Read};

use net2;
use td_revent::*;

use {EventMgr, SocketEvent};
pub struct ServiceMgr {
    listen_fds : HashSet<i32>,
}

static mut el : *mut ServiceMgr = 0 as *mut _;
impl ServiceMgr {
    pub fn instance() -> &'static mut ServiceMgr {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(ServiceMgr::new()));
            }
            &mut *el
        }
    }

    pub fn new() -> ServiceMgr {
        ServiceMgr {
            listen_fds : HashSet::new(),
        }
    }


    pub fn read_write_callback(ev : &mut EventLoop, fd : u32, flag : EventFlags, data : *mut ()) -> i32 {
        if flag.intersects(FLAG_READ) {
            Self::read_callback(ev, fd, flag, data);
        } else if flag.intersects(FLAG_WRITE) {
            Self::write_callback(ev, fd, flag, data);
        }
        0
    }

    fn read_callback(_ev : &mut EventLoop, fd : u32, _ : EventFlags, _ : *mut ()) -> i32 {
        let mut tcp = TcpStream::from_fd(fd as i32);
        let mut buffer = [0; 1024];
        let size = match tcp.read(&mut buffer) {
            Ok(size) => {
                if size == 0 {
                    EventMgr::instance().add_kick_event(fd as i32);
                    mem::forget(tcp);
                    return 0;
                }
                size
            },
            Err(_) => {
                println!("is error!!!!!!!!");
                EventMgr::instance().add_kick_event(fd as i32);
                mem::forget(tcp);
                return 0;
            }
        };
        EventMgr::instance().data_recieved(fd as i32, &buffer[..size]);
        mem::forget(tcp);
        0
    }

    fn write_callback(_ev : &mut EventLoop, _fd : u32, _ : EventFlags, _ : *mut ()) -> i32 {
        0
    }

    fn accept_callback(ev : &mut EventLoop, fd : u32, _ : EventFlags, _ : *mut ()) -> i32 {
        let listener = TcpListener::from_fd(fd as i32);
        let (stream, addr) = unwrap_or!(listener.accept().ok(), return 0);
        let local_addr = listener.local_addr().unwrap();
        let event = SocketEvent::new(stream.as_fd(), format!("{}", addr), local_addr.port());
        EventMgr::instance().new_socket_event(event);
        net2::TcpStreamExt::set_nonblocking(&stream, false).ok().unwrap();
        ev.add_event(EventEntry::new(stream.as_fd() as u32, FLAG_READ | FLAG_PERSIST, Some(ServiceMgr::read_write_callback), None));
        mem::forget(listener);
        mem::forget(stream);
        0
    }

    pub fn start_listener(&mut self, bind_ip : String, bind_port : u16) {
        let listener = TcpListener::bind(&format!("{}:{}", bind_ip, bind_port)[..]).unwrap();
        let fd = listener.as_fd();
        let event_loop = EventMgr::instance().get_event_loop();
        event_loop.add_event(EventEntry::new(listener.as_fd() as u32, FLAG_READ | FLAG_PERSIST, Some(ServiceMgr::accept_callback), None));
        self.listen_fds.insert(fd);
        mem::forget(listener);
    }

    pub fn stop_listener(&mut self) {
        let event_loop = EventMgr::instance().get_event_loop();
        for fd in &self.listen_fds {
            event_loop.del_event(*fd as u32, EventFlags::all());
        }
        self.listen_fds.clear();
    }

}