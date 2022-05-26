

extern crate ws;

use std::collections::HashMap;
use std::thread;
use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;

use ws::{Builder, Settings, CloseCode, Sender, Handler, Handshake, Message, Result, Error, ErrorKind};
use ws::util::{Token, Timeout};


use crate::{LuaEngine, NetMsg, SocketEvent, MioEventMgr, LogUtils, log_utils};

pub struct WebsocketClient {
    pub out: Sender,
    pub port: u16,
    pub unique: String,
    pub cookie: u32,
}

impl Handler for WebsocketClient {
    
    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = shake.remote_addr()? {
            addr = format!("{}", ip_addr);
        }
        
        self.unique = format!("WS:{}", self.out.token().0);

        let mut event = SocketEvent::new(self.unique.clone(), addr.to_string(), self.port);
        event.set_cookie(self.cookie);
        event.set_websocket(true);
        event.set_local(true);
        event.set_mio(true);

        MioEventMgr::instance().new_socket_event_lua(event);
        WebSocketMgr::instance().on_open(&self.unique, self.out.clone());
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        let net_msg = match msg {
            Message::Text(_text) => {
                WebSocketMgr::instance().on_close(&self.unique, &self.out, "未受支持的TEXT格式".to_string());
                // LuaEngine::instance().apply_lost_connect(&self.unique as SOCKET, "未受支持的TEXT格式".to_string());
                return Ok(());
            },
            Message::Binary(data) => {
                unwrap_or!(NetMsg::new_by_proto_data(&data[..]).ok(), {
                    WebSocketMgr::instance().on_close(&self.unique, &self.out, "解析二进制协议失败".to_string());
                    // LuaEngine::instance().apply_lost_connect(&self.unique as SOCKET, "解析二进制协议失败".to_string());
                    return Ok(())
                })
            },
        };

        LuaEngine::instance().apply_message(&self.unique, net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        WebSocketMgr::instance().on_close(&self.unique, &self.out, format!("WebSocket closing for ({:?}) {}", code, reason).to_string());
    }

    fn on_error(&mut self, err: Error) {
        // Shutdown on any error
        WebSocketMgr::instance().on_close(&self.unique, &self.out, format!("Shutting down server for error: {}", err).to_string());
    }

}


// Server WebSocket handler
#[derive(Clone)]
struct WebsocketServer {
    out: Sender,
    port: u16,
    unique: String,
    open_timeout: Option<Timeout>,
}

impl Handler for WebsocketServer {

    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = shake.remote_addr()? {
            addr = format!("{}", ip_addr);
        }


        if let Some(t) = self.open_timeout.take() {
            self.out.cancel(t)?
        }
        self.open_timeout = None;

        self.unique = format!("WS:{}", self.out.connection_id());
        let mut event = SocketEvent::new(self.unique.clone(), addr.to_string(), self.port);
        event.set_websocket(true);
        event.set_mio(true);

        MioEventMgr::instance().new_socket_event_lua(event);
        WebSocketMgr::instance().on_open(&self.unique, self.out.clone());
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        let net_msg = match msg {
            Message::Text(_text) => {
                // WebSocketMgr::instance().on_close(&self.unique, &self.out, "未受支持的TEXT格式".to_string());
                LuaEngine::instance().apply_lost_connect(&self.unique, "未受支持的TEXT格式".to_string());
                return Ok(());
            },
            Message::Binary(data) => {
                unwrap_or!(NetMsg::new_by_data(&data[..]).ok(), {
                    // WebSocketMgr::instance().on_close(&self.unique, &self.out, "解析二进制协议失败".to_string());
                    LuaEngine::instance().apply_lost_connect(&self.unique, "解析二进制协议失败".to_string());
                    return Ok(())
                })
            },
        };

        LuaEngine::instance().apply_message(&self.unique, net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        if let Some(t) = self.open_timeout.take() {
            let _ = self.out.cancel(t);
        }
        self.open_timeout = None;

        WebSocketMgr::instance().on_close(&self.unique, &self.out, format!("WebSocket closing for ({:?}) {}", code, reason).to_string());
    }

    fn on_error(&mut self, err: Error) {
        if let Some(t) = self.open_timeout.take() {
            let _ = self.out.cancel(t);
        }
        self.open_timeout = None;

        // Shutdown on any error
        WebSocketMgr::instance().on_close(&self.unique, &self.out, format!("Shutting down server for error: {}", err).to_string());
    }

    fn on_timeout(&mut self, _event: Token) -> Result<()> {
        trace!("wait connecting handshake!!!! on_timeout occur {}", self.unique);
        self.open_timeout = None;
        let _ = self.out.close(CloseCode::Normal);
        Ok(())
    }

    fn on_new_timeout(&mut self, _event: Token, timeout: Timeout) -> Result<()> {
        if let Some(t) = self.open_timeout.take() {
            self.out.cancel(t)?
        }
        self.open_timeout = Some(timeout);
        Ok(())
    }

}

// // For accessing the default handler implementation
// struct DefaultHandler;

// impl Handler for DefaultHandler {}



pub struct WebSocketMgr {
    port: u16,
    connect_ids: HashMap<String, Sender>,
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

    pub fn on_open(&mut self, unique: &String, sender: Sender) {
        let _data = self.mutex.lock().unwrap();
        self.connect_ids.insert(unique.clone(), sender);
    }

    pub fn on_close(&mut self, unique: &String, sender: &Sender, reason: String) {
        let _connect = {
            let _data = self.mutex.lock().unwrap();
            unwrap_or!(self.connect_ids.remove(unique), {
                let _ = sender.close_with_reason(CloseCode::Abnormal, reason);
                // let _ = sender.shutdown();
                return;
            })
        };
        MioEventMgr::instance().add_kick_event(unique, reason);
    }


    pub fn close_fd(&mut self, unique: &String) -> bool {
        let _data = self.mutex.lock().unwrap();
        if !self.connect_ids.contains_key(unique) {
            return false;
        }

        let info = format!("Server active Websocket ready close unique {:?}", unique);
        trace!("{}", info);
        LogUtils::instance().append(2, &*info);

        let sender = self.connect_ids.get_mut(unique).unwrap();
        let _ = sender.close(CloseCode::Normal);
        true
    }

    pub fn send_message(&mut self, unique: &String, net_msg: &mut NetMsg, is_local: bool) -> bool {
        let _data = self.mutex.lock().unwrap();
        if !self.connect_ids.contains_key(unique) {
            return false;
        }

        let sender = self.connect_ids.get_mut(unique).unwrap();
        net_msg.get_buffer().set_rpos(0);
        if is_local {
            let _ = sender.send(Message::binary(&net_msg.get_buffer().get_write_data()[..]));
        } else {
            let _ = sender.send(Message::binary(&net_msg.get_buffer().get_write_data()[26..]));
        }
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
                        unique: String::new(),
                        open_timeout: None,
                    };
                    // let token = server.out.token();
                    // let _ = server.out.timeout(15_000, token).ok();
                    server
                }).unwrap().listen(&*url);
                let websocket = &format!("websocket close exit may webscoket fd is closed!!!!")[..];
                trace!("{:?}", websocket);
                LogUtils::instance().append(log_utils::LOG_ERROR, websocket);
            }
        });
    }
}