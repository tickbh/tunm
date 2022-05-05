use std::collections::{HashSet, HashMap};
use psocket::{TcpSocket, SOCKET};
use std::any::Any;
use td_revent::*;

use websocket::{Connection, Handler, Settings, Handshake, Message, CloseCode ,Error, Result, ErrorKind};

use {LuaEngine, NetMsg, SocketEvent, EventMgr, LogUtils, TimeUtils};


#[derive(Clone)]
pub struct Server {
    fd: SOCKET,
    port: u16,
}

pub struct WebsocketMyMgr {
    listen_fds: HashSet<SOCKET>,
    close_fds: HashSet<SOCKET>,
    connection_fds: HashMap<SOCKET, Connection<Server>>,
    default: Settings,
    listen_port: u16,
}


static mut EL: *mut WebsocketMyMgr = 0 as *mut _;
impl WebsocketMyMgr {
    pub fn instance() -> &'static mut WebsocketMyMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(WebsocketMyMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> WebsocketMyMgr {
        WebsocketMyMgr {
            listen_fds: HashSet::new(),
            close_fds: HashSet::new(),
            connection_fds: HashMap::new(),
            default: Settings {
                    max_connections: 10_000,
                    in_buffer_capacity: 2048000,
                    out_buffer_capacity: 2048000,
                    ..Settings::default()
                },
            listen_port: 0,
        }
    }

    pub fn record_connection(&mut self) {
        let info = format!("Current connections len:{:?}, waiting close:{:?}", self.connection_fds.len(), self.close_fds);
        trace!("{}", info);
        LogUtils::instance().append(2, &*info);
    }

    pub fn get_connection(&mut self, fd: SOCKET) -> Option<&mut Connection<Server>> {
        self.connection_fds.get_mut(&fd)
    }

    pub fn server_read_callback(
        _ev: &mut EventLoop,
        buffer: &mut EventBuffer,
        _data: Option<&mut CellAny>,
    ) -> RetValue {
        let data = buffer.read.drain_all_collect();
        let mut close_atsoon = false;
        let mut err_str = String::new();
        {
            let connect = unwrap_or!(WebsocketMyMgr::instance().get_connection(buffer.as_raw_socket()), {
                trace!("read_callback error occur fd ={:?} but the connection is missing", buffer.as_raw_socket());
                return RetValue::OVER;
            });

            connect.new_data_received(&data[..]);
            connect.set_read_time(TimeUtils::get_time_ms());


            if let Err(err) = connect.read() {
                trace!("read_callback err occur = {:?}", err);
                err_str = format!("{:?}", err).to_string();
                match err.kind {
                    ErrorKind::CloseSingal | ErrorKind::OutNotEnough | ErrorKind::Io(_) => {
                        close_atsoon = true;
                    },
                    _ => {
                        if connect.is_closing() {
                            close_atsoon = true;
                        } else {
                            let _ = connect.send_close(CloseCode::Abnormal, "read error");
                        }
                    },
                }

                if connect.is_over() {
                    close_atsoon = true;
                }
            }
        }

        if close_atsoon {
            WebsocketMyMgr::instance().on_close(buffer.as_raw_socket(), err_str);
            return RetValue::OVER;
        }

        RetValue::OK
    }

    pub fn server_end_callback(_ev: &mut EventLoop, buffer: &mut EventBuffer, _data: Option<CellAny>) {
        WebsocketMyMgr::instance().on_close(buffer.as_raw_socket(), String::new());
    }

    fn accept_callback(
        ev: &mut EventLoop,
        tcp: ::std::io::Result<TcpSocket>,
        data: Option<&mut CellAny>,
    ) -> RetValue {
        if tcp.is_err() {
            return RetValue::OK;
        }

        let instance = WebsocketMyMgr::instance();
        
        // let cellany = data.unwrap();
        // let obj = any_to_mut!(cellany, Point);
        // obj.y = obj.y + 1;
        // if obj.y >= 25 {
        //     return (RetValue::OK, 0);
        // }
        // println!("callback {:?}", obj);
        // return (RetValue::CONTINUE, 10);

        let port = any_to_ref!(data.unwrap(), u16).clone();
        let new_socket = tcp.unwrap();
        let stream = new_socket.clone();
        let _ = new_socket.set_nonblocking(true);
        //设置2m的写缓冲
        new_socket.set_send_size(2 * 1024 * 1024).ok().unwrap();
        //设置2m的读缓冲
        new_socket.set_recv_size(2 * 1024 * 1024).ok().unwrap();

        let socket = new_socket.as_raw_socket();
        let mut event = SocketEvent::new(socket, format!("{}", new_socket.peer_addr().unwrap()), port);
        event.set_websocket(true);
        event.set_mio(false);
        EventMgr::instance().receive_socket_event(event);

        if instance.close_fds.contains(&socket) {
            let info = format!("Error!!!!!!!!!! close_fds[{}] exist, when accept socket", socket);
            trace!("{}", info);
            LogUtils::instance().append(2, &*info);
        }
        instance.close_fds.remove(&socket);

        let buffer = ev.new_buff(new_socket);
        let _ = ev.register_socket(
            buffer,
            EventEntry::new_event(
                socket,
                EventFlags::FLAG_READ | EventFlags::FLAG_PERSIST,
                Some(Self::server_read_callback),
                None,
                Some(Self::server_end_callback),
                None,
            ),
        );


        let server = Server {
            fd: socket,
            port: port,
        };
        let connect = Connection::new(stream.convert_to_stream(), server, instance.default.clone());
        instance.connection_fds.insert(socket, connect);
        instance.record_connection();

        // TcpMgr::instance().insert_stream(stream.as_fd(), stream);
        
        RetValue::OK
    }

    pub fn on_close(&mut self, fd: SOCKET, reason: String) {
        if self.close_fds.contains(&fd) {
            return;
        }
        self.close_fds.insert(fd);
        EventMgr::instance().add_kick_event(fd, reason);
    }

    pub fn remove_socket(&mut self, fd: SOCKET) {
        self.close_fds.remove(&fd);
        self.connection_fds.remove(&fd);
    }


    pub fn send_message(&mut self, fd: SOCKET, net_msg: &mut NetMsg) -> bool {
        if !self.connection_fds.contains_key(&fd) {
            return false;
        }

        if net_msg.get_buffer().len() <= 12 {
            return false;
        }

        let connect = self.connection_fds.get_mut(&fd).unwrap();
        if let Err(err) = connect.send_message(Message::binary(&net_msg.get_buffer().get_data()[12..])) {
            WebsocketMyMgr::instance().on_close(fd, format!("{:?}", err).to_string());
        }
        true
    }

    pub fn close_fd(&mut self, fd: SOCKET) -> bool {
        if self.close_fds.contains(&fd) {
            return true;
        }

        let info = format!("Server active Websocket ready close fd {:?}", fd);
        println!("{}", info);
        LogUtils::instance().append(2, &*info);

        let connect = unwrap_or!(WebsocketMyMgr::instance().get_connection(fd), return false);
        let _ = connect.send_close(CloseCode::Normal, "Server Close Socket");
        true
    }

    fn timer_check_callback(
        _ev: &mut EventLoop,
        _timer: u32,
        _data: Option<&mut CellAny>,
    ) -> (RetValue, u64) {
        let instance = WebsocketMyMgr::instance();
        let mut close_fds: HashSet<SOCKET> = HashSet::new();
        let now = TimeUtils::get_time_ms();
        for (fd, connect) in &instance.connection_fds {
            //10分钟未收到read则断开
            if now - connect.get_read_time() > 600_000 {
                close_fds.insert(*fd);
            }
        }

        if close_fds.len() > 0 {
            let info = format!("Has long time not read fds:{:?}", close_fds);
            println!("{}", info);
            LogUtils::instance().append(2, &*info);
        }

        for fd in &close_fds {
            WebsocketMyMgr::instance().on_close(*fd, "WebSocket closing for long time not read".to_string());
        }

        (RetValue::OK, 0)
    }

    pub fn start_listen(&mut self, bind_ip: String, bind_port: u16) {
        let listener = TcpSocket::bind(&format!("{}:{}", bind_ip, bind_port)[..]).unwrap();
        self.listen_port = bind_port;
        let socket = listener.as_raw_socket();
        let event_loop = EventMgr::instance().get_event_loop();
        let buffer = event_loop.new_buff(listener);
        let _ = event_loop.register_socket(
            buffer,
            EventEntry::new_accept(
                socket,
                EventFlags::FLAG_READ | EventFlags::FLAG_PERSIST | EventFlags::FLAG_ACCEPT,
                Some(Self::accept_callback),
                None,
                Some(Box::new(bind_port)),
            ),
        );
        
        event_loop.add_timer(EventEntry::new_timer(6_000_000,
                                             true,
                                             Some(Self::timer_check_callback),
                                             None));

        self.listen_fds.insert(socket);


    }

    pub fn stop_listen(&mut self) {
        let event_loop = EventMgr::instance().get_event_loop();
        for fd in &self.listen_fds {
            let _ = event_loop.unregister_socket(*fd);
        }
        self.listen_fds.clear();
    }
}


impl Handler for Server {

    fn on_open(&mut self, shake: Handshake) -> Result<()> {
        let mut addr = "unkown_ip".to_string();
        if let Some(ip_addr) = try!(shake.remote_addr()) {
            addr = format!("{}", ip_addr);
        }

        let mut event = SocketEvent::new(self.fd, addr.to_string(), self.port);
        event.set_websocket(true);
        event.set_mio(false);

        EventMgr::instance().new_socket_event(event);

        Ok(())
    }

    fn on_message(&mut self, msg: Message) -> Result<()> {
        let net_msg = match msg {
            Message::Text(_text) => {
                return Ok(());
            },
            Message::Binary(data) => {
                unwrap_or!(NetMsg::new_by_proto_data(&data[..]).ok(), return Ok(()))
            },
        };

        LuaEngine::instance().apply_message(self.fd, net_msg);
        Ok(())
    }

    fn on_close(&mut self, code: CloseCode, reason: &str) {
        WebsocketMyMgr::instance().on_close(self.fd, format!("WebSocket closing for ({:?}) {}", code, reason).to_string());
    }

    fn on_error(&mut self, err: Error) {
        WebsocketMyMgr::instance().on_close(self.fd, format!("Shutting down server for error: {}", err).to_string());
    }

}