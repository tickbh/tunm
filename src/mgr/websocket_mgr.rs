

extern crate ws;
extern crate time;

use std::collections::HashMap;
use std::thread;
use std::str::from_utf8;

use std::sync::Arc;
use td_rthreadpool::ReentrantMutex;

use ws::{Builder, Settings, listen, CloseCode, OpCode, Sender, Frame, Handler, Handshake, Message, Result, Error, ErrorKind};
use ws::util::{Token, Timeout};

use {ProtocolMgr, LuaEngine, NetMsg, SocketEvent, EventMgr, MSG_TYPE_TEXT, MSG_TYPE_BIN, MSG_TYPE_JSON};

const PING: Token = Token(1);
const EXPIRE: Token = Token(2);

// Server WebSocket handler
#[derive(Clone)]
struct Server {
    out: Sender,
    port: u16,
}

impl Handler for Server {

    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = try!(shake.remote_addr()) {
            addr = format!("{}", ip_addr);
        }

        let mut event = SocketEvent::new(self.out.fd(), addr.to_string(), self.port);
        event.set_websocket(true);
        EventMgr::instance().new_socket_event(event);
        WebSocketMgr::instance().on_open(self.out.clone());
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        println!("Server got message '{}'. ", msg);
        self.out.send(msg.clone());

        let net_msg = match msg {
            Message::Text(text) => {
                let mut first = 0;
                let mut last = 0;
                let data = &text.as_bytes();
                for i in 0 .. data.len() {
                    if data[i] == '"' as u8 {
                        if first == 0 {
                            first = i;
                        } else if last == 0 {
                            last = i;
                            break;
                        }
                    }
                }
                let name = String::from_utf8_lossy(&data[first + 1 .. last]).to_string();
                println!("name = {}", name);
                NetMsg::new_by_detail(MSG_TYPE_TEXT, name, &text.as_bytes()[..])

            },
            Message::Binary(data) => NetMsg::new_by_detail(MSG_TYPE_BIN, "web_socket_binary".to_string(), &data[..]),
        };

        LuaEngine::instance().apply_message(self.out.fd(), net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        println!("WebSocket closing for ({:?}) {}", code, reason);

        EventMgr::instance().add_kick_event(self.out.fd());

        WebSocketMgr::instance().on_close(&self.out);
    }

    fn on_error(&mut self, err: Error) {
        // Shutdown on any error
        println!("Shutting down server for error: {}", err);
        EventMgr::instance().add_kick_event(self.out.fd());
        WebSocketMgr::instance().on_close(&self.out);
    }


    // fn on_frame(&mut self, frame: Frame) -> Result<Option<Frame>> {
    //     println!("recv frame {:?}", frame);
    //     // If the frame is a pong, print the round-trip time.
    //     // The pong should contain data from out ping, but it isn't guaranteed to.
    //     if frame.opcode() == OpCode::Pong {
    //         if let Ok(pong) = try!(from_utf8(frame.payload())).parse::<u64>() {
    //             let now = time::precise_time_ns();
    //             println!("RTT is {:.3}ms.", (now - pong) as f64 / 1_000_000f64);
    //         } else {
    //             println!("Received bad pong.");
    //         }
    //     }

    //     // Some activity has occured, so reset the expiration
    //     try!(self.out.timeout(30_000, EXPIRE));

    //     // Run default frame validation
    //     DefaultHandler.on_frame(frame)
    // }
}

// For accessing the default handler implementation
struct DefaultHandler;

impl Handler for DefaultHandler {}



pub struct WebSocketMgr {
    port: u16,
    connect_ids: HashMap<i32, Sender>,
    mutex: Arc<ReentrantMutex<u32>>,
}

static mut el: *mut WebSocketMgr = 0 as *mut _;
impl WebSocketMgr {
    pub fn instance() -> &'static mut WebSocketMgr {
        unsafe {
            if el == 0 as *mut _ {
                el = Box::into_raw(Box::new(WebSocketMgr::new()));
            }
            &mut *el
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
        let mut data = self.mutex.lock().unwrap();
        self.connect_ids.insert(sender.fd(), sender);
    }

    pub fn on_close(&mut self, sender: &Sender) {
        let mut data = self.mutex.lock().unwrap();
        self.connect_ids.remove(&sender.fd());
    }

    pub fn send_message(&mut self, fd: i32, net_msg: &mut NetMsg) -> bool {
        let mut data = self.mutex.lock().unwrap();
        if !self.connect_ids.contains_key(&fd) {
            return false;
        }
        let sender = self.connect_ids.get_mut(&fd).unwrap();
        let msg = unwrap_or!(ProtocolMgr::instance().convert_string(LuaEngine::instance().get_lua().state(), net_msg).ok(), return false);
        println!("!!!!!!!!!!!!!!!!!!!msg = {:?}", msg);
        sender.send(Message::Text(msg));
        true
    }

    pub fn start_listen(&mut self, url: String, port: u16) {
        let url = format!("{}:{}", url, port);
        self.port = port;
        thread::spawn(move || {
            Builder::new().with_settings(Settings {
                max_connections: 10_000,
                in_buffer_capacity: 2048000,
                out_buffer_capacity: 2048000,
                ..Settings::default()
            }).build(|out : Sender| {
                let a= out.clone();
                Server {
                    out: out,
                    port: port,
                }
            }).unwrap().listen(&*url);
        });

    }
}