

extern crate ws;
extern crate time;

use std::thread;
use std::str::from_utf8;

use ws::{Builder, Settings, listen, CloseCode, OpCode, Sender, Frame, Handler, Handshake, Message, Result, Error, ErrorKind};
use ws::util::{Token, Timeout};

use {LuaEngine, NetMsg, SocketEvent, EventMgr, MSG_TYPE_TEXT, MSG_TYPE_BIN, MSG_TYPE_JSON};

const PING: Token = Token(1);
const EXPIRE: Token = Token(2);

// Server WebSocket handler
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
        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        println!("Server got message '{}'. ", msg);
        self.out.send(msg.clone());

        let net_msg = match msg {
            Message::Text(text) => NetMsg::new_by_detail(MSG_TYPE_TEXT, "web_socket_text".to_string(), &text.as_bytes()[..]),
            Message::Binary(data) => NetMsg::new_by_detail(MSG_TYPE_BIN, "web_socket_binary".to_string(), &data[..]),
        };

        LuaEngine::instance().apply_message(self.out.fd(), net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        println!("WebSocket closing for ({:?}) {}", code, reason);

        EventMgr::instance().add_kick_event(self.out.fd());
    }

    fn on_error(&mut self, err: Error) {
        // Shutdown on any error
        println!("Shutting down server for error: {}", err);
        EventMgr::instance().add_kick_event(self.out.fd());
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
        WebSocketMgr { port: 0 }
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
                Server {
                    out: out,
                    port: port,
                }
            }).unwrap().listen(&*url);
        });

    }
}