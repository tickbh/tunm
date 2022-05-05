use td_rp::Buffer;
use psocket::{SOCKET};

#[derive(Debug)]
pub struct SocketEvent {
    socket_fd: SOCKET,
    cookie: u32,
    client_ip: String,
    server_port: u16,
    buffer: Buffer,
    out_cache: Buffer,
    online: bool,
    websocket: bool,
    local: bool, //is local create fd
    mio: bool,
}

impl SocketEvent {
    pub fn new(socket_fd: SOCKET, client_ip: String, server_port: u16) -> SocketEvent {
        SocketEvent {
            socket_fd: socket_fd,
            cookie: 0,
            client_ip: client_ip,
            server_port: server_port,
            buffer: Buffer::new(),
            out_cache: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
        }
    }

    pub fn get_socket_fd(&self) -> i32 {
        self.socket_fd as i32
    }
    
    pub fn as_raw_socket(&self) -> SOCKET {
        self.socket_fd
    }

    pub fn get_client_ip(&self) -> String {
        self.client_ip.clone()
    }

    pub fn get_server_port(&self) -> u16 {
        self.server_port
    }

    pub fn get_cookie(&self) -> u32 {
        self.cookie
    }

    pub fn set_cookie(&mut self, cookie: u32) {
        self.cookie = cookie;
    }

    pub fn get_buffer(&mut self) -> &mut Buffer {
        &mut self.buffer
    }

    pub fn get_out_cache(&mut self) -> &mut Buffer {
        &mut self.out_cache
    }

    pub fn set_online(&mut self, online: bool) {
        self.online = online;
    }

    pub fn is_online(&self) -> bool {
        self.online
    }

    pub fn set_websocket(&mut self, websocket: bool) {
        self.websocket = websocket;
    }

    pub fn is_websocket(&self) -> bool {
        self.websocket
    }

    pub fn set_local(&mut self, local: bool) {
        self.local = local;
    }

    pub fn is_local(&self) -> bool {
        self.local
    }

    pub fn set_mio(&mut self, mio: bool) {
        self.mio = mio;
    }

    pub fn is_mio(&self) -> bool {
        self.mio
    }
}
