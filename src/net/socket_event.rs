use tunm_proto::Buffer;
use psocket::{SOCKET};
use mio::{Poll, Token};
use mio::net::{TcpListener, TcpStream};
use crate::net::AsSocket;

use std::io::{self, Read, Write};
use std::io::Result;

pub type AcceptCb = fn(&mut SocketEvent) -> usize;
pub type ReadCb = fn(&mut SocketEvent) -> usize;
pub type WriteCb = fn(&mut SocketEvent) -> usize;
pub type EndCb = fn(&mut SocketEvent);

// #[derive(Debug)]
pub struct SocketEvent {
    unique: String,
    cookie: u32,
    client_ip: String,
    token: Token,
    server_port: u16,
    pub in_buffer: Buffer,
    pub out_buffer: Buffer,
    online: bool,
    websocket: bool,
    local: bool, //is local create fd
    mio: bool,
    server: Option<TcpListener>,
    client: Option<TcpStream>,
    pub accept: Option<AcceptCb>,
    pub read: Option<ReadCb>,
    pub write: Option<WriteCb>,
    pub end: Option<EndCb>,
}

impl SocketEvent {
    pub fn new(unique: String, client_ip: String, server_port: u16) -> SocketEvent {
        SocketEvent {
            unique: unique,
            cookie: 0,
            client_ip: client_ip,
            token: Token(0),
            server_port: server_port,
            in_buffer: Buffer::new(),
            out_buffer: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
            server: None,
            client: None,
            accept: None,
            read: None,
            write: None,
            end: None,
        }
    }
    
    pub fn new_client(client: TcpStream, server_port: u16) -> SocketEvent {
        let token = Token(client.as_socket() as usize);
        let peer = format!("{}", client.peer_addr().unwrap());
        SocketEvent {
            unique: Self::token_to_unique(&token), 
            cookie: 0,
            client_ip: peer,
            token: token,
            server_port: server_port,
            in_buffer: Buffer::new(),
            out_buffer: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
            server: None,
            client: Some(client),
            accept: None,
            read: None,
            write: None,
            end: None,
        }
    }
    
    pub fn new_server(server: TcpListener, server_port: u16) -> SocketEvent {
        let token = Token(server.as_socket() as usize);
        SocketEvent {
            unique: Self::token_to_unique(&token),
            cookie: 0,
            client_ip: "".to_string(),
            token: token,
            server_port: server_port,
            in_buffer: Buffer::new(),
            out_buffer: Buffer::new(),
            online: true,
            websocket: false,
            local: false,
            mio: false,
            server: Some(server),
            client: None,
            accept: None,
            read: None,
            write: None,
            end: None,
        }
    }

    pub fn get_unique(&self) -> &String {
        &self.unique
    }
    
    // pub fn as_raw_socket(&self) -> SOCKET {
    //     self.unique
    // }

    pub fn token_to_unique(token: &Token) -> String {
        format!("NM:{}", token.0)
    }

    pub fn unique_to_token(unique: &String) -> Token {
        let s = unique.get(3..).unwrap_or("0");
        Token(s.parse::<usize>().ok().unwrap_or(0))
    }

    pub fn as_token(&self) -> Token {
        self.token
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

    pub fn get_in_buffer(&mut self) -> &mut Buffer {
        &mut self.in_buffer
    }

    pub fn get_out_buffer(&mut self) -> &mut Buffer {
        &mut self.out_buffer
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
    
    pub fn read_data(&mut self) -> Result<bool> {
        let mut bytes_read = 0;
        loop {
            match self.client.as_mut().unwrap().read(self.in_buffer.get_read_array(2048)) {
                Ok(0) => {
                    return Ok(true);
                }
                Ok(n) => {
                    bytes_read += n;
                    self.in_buffer.write_offset(n);
                    if bytes_read > 655360 {
                        trace!("too big data");
                        return Ok(true);
                    }

                    //  else if bytes_read < 2048 {
                    //     break;
                    // }
                }
                // Would block "errors" are the OS's way of saying that the
                // connection is not actually ready to perform this I/O operation.
                Err(ref err) if err.kind() == io::ErrorKind::WouldBlock => break,
                Err(ref err) if err.kind() == io::ErrorKind::Interrupted => continue,
                // Other errors we'll consider fatal.
                Err(err) => return Ok(true),
            }
        }
        Ok(false)
    }

    pub fn write_data(&mut self) -> Result<bool> {
        let size = self.client.as_mut().unwrap().write(self.out_buffer.get_write_data())?;
        Ok(self.out_buffer.read_offset(size))
    }

    pub fn set_accept(&mut self, accept: Option<AcceptCb>) {
        self.accept = accept;
    }

    pub fn call_accept(&self, client: &mut SocketEvent) -> usize {
        if self.accept.is_some() {
            self.accept.as_ref().unwrap()(client)
        } else {
            0
        }
    }
    
    pub fn set_read(&mut self, read: Option<ReadCb>) {
        self.read = read;
    }
    
    pub fn call_read(&mut self) -> usize {
        if self.read.is_some() {
            self.read.as_ref().clone().unwrap()(self)
        } else {
            0
        }
    }

    
    pub fn set_write(&mut self, write: Option<WriteCb>) {
        self.write = write;
    }

    pub fn call_write(&mut self, client: &mut SocketEvent) -> usize {
        if self.write.is_some() {
            self.write.as_ref().unwrap()(client)
        } else {
            0
        }
    }
    
    pub fn set_end(&mut self, end: Option<EndCb>) {
        self.end = end;
    }
    
    pub fn call_end(&mut self) {
        if self.end.is_some() {
            self.end.as_ref().clone().unwrap()(self);
        }
    }
}
