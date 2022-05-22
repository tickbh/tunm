

extern crate ws;

use std::collections::HashMap;
use std::thread;
use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;
use psocket::SOCKET;

use ws::{Builder, Settings, CloseCode, Sender, Handler, Handshake, Message, Result, Error, ErrorKind};
use ws::util::{Token, Timeout};

use {LuaEngine, NetMsg, SocketEvent, EventMgr, MioEventMgr, MSG_TYPE_TEXT, LogUtils, log_utils};

const CONNECT: Token = Token(1);

pub struct WebsocketClient {
    pub out: Sender,
    pub port: u16,
    pub socket: usize,
    pub cookie: u32,
}

impl Handler for WebsocketClient {
    
    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = shake.remote_addr()? {
            addr = format!("{}", ip_addr);
        }

        let mut event = SocketEvent::new(self.socket as SOCKET, addr.to_string(), self.port);
        event.set_cookie(self.cookie);
        event.set_websocket(true);
        event.set_mio(true);

        MioEventMgr::instance().new_socket_event(event);
        WebSocketMgr::instance().on_open(self.out.clone());
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        let net_msg = match msg {
            Message::Text(_text) => {
                LuaEngine::instance().apply_lost_connect(self.socket as SOCKET, "未受支持的TEXT格式".to_string());
                return Ok(());
            },
            Message::Binary(data) => {
                unwrap_or!(NetMsg::new_by_data(&data[..]).ok(), {
                    LuaEngine::instance().apply_lost_connect(self.socket as SOCKET, "解析二进制协议失败".to_string());
                    return Ok(())
                })
            },
        };

        LuaEngine::instance().apply_message(self.socket as SOCKET, net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        WebSocketMgr::instance().on_close(&self.out, format!("WebSocket closing for ({:?}) {}", code, reason).to_string());
    }

    fn on_error(&mut self, err: Error) {
        // Shutdown on any error
        WebSocketMgr::instance().on_close(&self.out, format!("Shutting down server for error: {}", err).to_string());
    }

}


// Server WebSocket handler
#[derive(Clone)]
struct WebsocketServer {
    out: Sender,
    port: u16,
    socket: usize,
    open_timeout: Option<Timeout>,
}

impl Handler for WebsocketServer {

    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = shake.remote_addr()? {
            addr = format!("{}", ip_addr);
        }

        self.socket = shake.socket;

        if let Some(t) = self.open_timeout.take() {
            self.out.cancel(t)?
        }
        self.open_timeout = None;

        let mut event = SocketEvent::new(shake.socket as SOCKET, addr.to_string(), self.port);
        event.set_websocket(true);
        event.set_mio(true);

        EventMgr::instance().new_socket_event(event);
        WebSocketMgr::instance().on_open(self.out.clone());
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        let net_msg = match msg {
            Message::Text(_text) => {
                LuaEngine::instance().apply_lost_connect(self.socket as SOCKET, "未受支持的TEXT格式".to_string());
                return Ok(());
            },
            Message::Binary(data) => {
                unwrap_or!(NetMsg::new_by_data(&data[..]).ok(), {
                    LuaEngine::instance().apply_lost_connect(self.socket as SOCKET, "解析二进制协议失败".to_string());
                    return Ok(())
                })
            },
        };

        LuaEngine::instance().apply_message(self.socket as SOCKET, net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        if let Some(t) = self.open_timeout.take() {
            let _ = self.out.cancel(t);
        }
        self.open_timeout = None;

        WebSocketMgr::instance().on_close(&self.out, format!("WebSocket closing for ({:?}) {}", code, reason).to_string());
    }

    fn on_error(&mut self, err: Error) {
        if let Some(t) = self.open_timeout.take() {
            let _ = self.out.cancel(t);
        }
        self.open_timeout = None;

        // Shutdown on any error
        WebSocketMgr::instance().on_close(&self.out, format!("Shutting down server for error: {}", err).to_string());
    }

    fn on_timeout(&mut self, event: Token) -> Result<()> {
        match event {
            CONNECT => {
                trace!("wait connecting handshake!!!! on_timeout occur {}", self.socket);
                self.open_timeout = None;
                let _ = self.out.close(CloseCode::Normal);
                Ok(())
            },
            _ => {
                Err(Error::new(ErrorKind::Internal, "Invalid timeout token encountered!"))
            }
        }
    }


    fn on_new_timeout(&mut self, event: Token, timeout: Timeout) -> Result<()> {
        // Cancel the old timeout and replace.
        if event == CONNECT {
            if let Some(t) = self.open_timeout.take() {
                self.out.cancel(t)?
            }
            self.open_timeout = Some(timeout);
        }
        Ok(())
    }

}

// // For accessing the default handler implementation
// struct DefaultHandler;

// impl Handler for DefaultHandler {}



pub struct WebSocketMgr {
    port: u16,
    connect_ids: HashMap<i32, Sender>,
    mutex: Arc<ReentrantMutex<u32>>,
}

static mut EL: *mut WebSocketMgr = 0 as *mut _;
impl WebSocketMgr {
    pub fn instance() -> &'static mut WebSocketMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(WebSocketMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> WebSocketMgr {
        WebSocketMgr { 
            port: 0, 
            connect_ids: HashMap::new(),
            mutex: Arc::new(ReentrantMutex::new(0))
        }
    }

    pub fn on_open(&mut self, sender: Sender) {
        let _data = self.mutex.lock().unwrap();
        self.connect_ids.insert(sender.connection_id() as i32, sender);
    }

    pub fn on_close(&mut self, sender: &Sender, reason: String) {
        let connect = {
            let _data = self.mutex.lock().unwrap();
            unwrap_or!(self.connect_ids.remove(&(sender.connection_id() as i32)), return)
        };
        EventMgr::instance().add_kick_event(connect.connection_id() as SOCKET, reason);
    }


    pub fn close_fd(&mut self, fd: i32) -> bool {
        let _data = self.mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }

        let info = format!("Server active Websocket ready close fd {:?}", fd);
        trace!("{}", info);
        LogUtils::instance().append(2, &*info);

        let sender = self.connect_ids.get_mut(&fd).unwrap();
        let _ = sender.close(CloseCode::Normal);
        true
    }

    pub fn send_message(&mut self, fd: i32, net_msg: &mut NetMsg) -> bool {
        let _data = self.mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }

        let sender = self.connect_ids.get_mut(&fd).unwrap();
        let _ = sender.send(Message::binary(&net_msg.get_buffer().get_data()[12..]));

        // let msg = unwrap_or!(ProtocolMgr::instance().convert_string(LuaEngine::instance().get_lua().state(), net_msg).ok(), return false);
        // sender.send(Message::Text(msg));
        true
    }

    pub fn start_listen(&mut self, url: String, port: u16) {
        let url = format!("{}:{}", url, port);
        self.port = port;
        let _ = thread::Builder::new().name("webscoket".to_owned()).spawn(move || {
            loop {
                let _ = Builder::new().with_settings(Settings {
                    max_connections: 10_000,
                    in_buffer_capacity: 2048000,
                    out_buffer_capacity: 2048000,
                    ..Settings::default()
                }).build(|out : Sender| {
                    let server = WebsocketServer {
                        out: out,
                        port: port,
                        socket: 0,
                        open_timeout: None,
                    };
                    let _ = server.out.timeout(15_000, CONNECT).ok();
                    server
                }).unwrap().listen(&*url);
                let websocket = &format!("websocket close exit may webscoket fd is closed!!!!")[..];
                trace!("{:?}", websocket);
                LogUtils::instance().append(log_utils::LOG_ERROR, websocket);
            }
        });
    }
}