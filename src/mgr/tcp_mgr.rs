use std::collections::HashMap;
use std::net::{TcpListener, TcpStream};

pub struct TcpMgr {
    stream_fds: HashMap<i32, TcpStream>,
    listen_fds: HashMap<i32, TcpListener>,
}

static mut EL: *mut TcpMgr = 0 as *mut _;
impl TcpMgr {
    pub fn instance() -> &'static mut TcpMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(TcpMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> TcpMgr {
        TcpMgr { 
            stream_fds: HashMap::new(),
            listen_fds: HashMap::new(),
        }
    }

    pub fn insert_stream(&mut self, fd: i32, stream: TcpStream) {
        self.stream_fds.insert(fd, stream);
    }

    pub fn remove_stream(&mut self, fd: i32) {
        self.stream_fds.remove(&fd);
    }

    pub fn get_stream(&mut self, fd: i32) -> Option<&mut TcpStream> {
        self.stream_fds.get_mut(&fd)
    }

    pub fn insert_listen(&mut self, fd: i32, listen: TcpListener) {
        self.listen_fds.insert(fd, listen);
    }

    pub fn remove_listen(&mut self, fd: i32) {
        self.listen_fds.remove(&fd);
    }

    pub fn get_listen(&mut self, fd: i32) -> Option<&mut TcpListener> {
        self.listen_fds.get_mut(&fd)
    }

}