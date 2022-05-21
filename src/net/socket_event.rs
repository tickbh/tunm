use tunm_proto::Buffer;
use psocket::{SOCKET};
use mio::Token;
use mio::net::{TcpListener, TcpStream};
use crate::net::AsSocket;

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
    server: Option<TcpListener>,
    client: Option<TcpStream>,
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
            server: None,
            client: None,
        }
    }
    
    pub fn new_client(client: TcpStream, server_port: u16) -> SocketEvent {
        let peer = format!("{}", client.peer_addr().unwrap());
        SocketEvent {
            socket_fd: client.as_socket() as SOCKET,
            cookie: 0,
            client_ip: peer,
            server_port: server_port,
            buffer: Buffer::new(),
            out_cache: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
            server: None,
            client: Some(client),
        }
    }
    
    pub fn new_server(server: TcpListener, server_port: u16) -> SocketEvent {
        SocketEvent {
            socket_fd: server.as_socket() as SOCKET,
            cookie: 0,
            client_ip: "".to_string(),
            server_port: server_port,
            buffer: Buffer::new(),
            out_cache: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
            server: Some(server),
            client: None,
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

    
    pub fn set_server(&mut self, server: TcpListener) {
        self.server = Some(server);
    }

    pub fn is_server(&self) -> bool {
        self.server.is_some()
    }
    
    pub fn as_server(&mut self) -> Option<&mut TcpListener> {
        self.server.as_mut()
    }

    
    pub fn set_client(&mut self, client: TcpStream) {
        self.client = Some(client);
    }

    pub fn is_client(&self) -> bool {
        self.client.is_some()
    }
    
    pub fn as_client(&mut self) -> Option<&mut TcpStream> {
        self.client.as_mut()
    }
}
