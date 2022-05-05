use std::collections::HashSet;
use std::any::Any;
use psocket::{TcpSocket, SOCKET};
use std::io::Result;

use td_revent::*;

use {EventMgr, SocketEvent};
pub struct ServiceMgr {
    listen_fds: HashSet<SOCKET>,
}

static mut EL: *mut ServiceMgr = 0 as *mut _;
impl ServiceMgr {
    pub fn instance() -> &'static mut ServiceMgr {
        unsafe {
            if EL == 0 as *mut _ {
                EL = Box::into_raw(Box::new(ServiceMgr::new()));
            }
            &mut *EL
        }
    }

    pub fn new() -> ServiceMgr {
        ServiceMgr { listen_fds: HashSet::new() }
    }

    pub fn server_read_callback(
        _ev: &mut EventLoop,
        buffer: &mut EventBuffer,
        _data: Option<&mut CellAny>,
    ) -> RetValue {
        let data = buffer.read.drain_all_collect();
        EventMgr::instance().data_recieved(buffer.as_raw_socket(), &data[..]);
        RetValue::OK
    }

    pub fn server_end_callback(_ev: &mut EventLoop, buffer: &mut EventBuffer, _data: Option<CellAny>) {
        EventMgr::instance().notify_connect_lost(buffer.as_raw_socket());
    }

    fn accept_callback(
        ev: &mut EventLoop,
        tcp: Result<TcpSocket>,
        data: Option<&mut CellAny>,
    ) -> RetValue {
        if tcp.is_err() {
            return RetValue::OK;
        }
        
        let port = any_to_ref!(data.unwrap(), u16);

        let new_socket = tcp.unwrap();
        let _ = new_socket.set_nonblocking(true);
        let socket = new_socket.as_raw_socket();
        let event = SocketEvent::new(socket, format!("{}", new_socket.peer_addr().unwrap()), port.clone());
        EventMgr::instance().new_socket_event(event);

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

        // TcpMgr::instance().insert_stream(stream.as_fd(), stream);
        
        RetValue::OK
    }

    pub fn start_listener(&mut self, bind_ip: String, bind_port: u16) {
        let listener = TcpSocket::bind(&format!("{}:{}", bind_ip, bind_port)[..]).unwrap();
        let event_loop = EventMgr::instance().get_event_loop();
        let socket = listener.as_raw_socket();
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
        self.listen_fds.insert(socket);
    }

    pub fn stop_listener(&mut self) {
        let event_loop = EventMgr::instance().get_event_loop();
        for fd in &self.listen_fds {
            let _ = event_loop.unregister_socket(*fd);
        }
        self.listen_fds.clear();
    }
}
