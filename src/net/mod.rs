mod net_msg;
mod socket_event;

pub use self::net_msg::NetMsg;
pub use self::net_msg::MSG_TYPE_TD;
pub use self::net_msg::MSG_TYPE_JSON;
pub use self::net_msg::MSG_TYPE_BIN;
pub use self::net_msg::MSG_TYPE_TEXT;
pub use self::socket_event::{SocketEvent, ReadCb, AcceptCb, WriteCb, EndCb};


#[cfg(unix)]
use std::os::unix::io::{AsRawFd};
#[cfg(target_os = "wasi")]
use std::os::wasi::io::{AsRawFd};
#[cfg(windows)]
use std::os::windows::io::{AsRawSocket};

pub trait AsSocket {
    fn as_socket(&self) -> usize;
    
}
use mio::net::{TcpListener, TcpStream};

impl AsSocket for TcpStream {
    #[cfg(unix)]
    fn as_socket(&self) -> usize {
        return self.as_raw_fd() as usize;
    }
    
    #[cfg(windows)]
    fn as_socket(&self) -> usize {
        return self.as_raw_socket() as usize;
    }
}


impl AsSocket for TcpListener {
    #[cfg(unix)]
    fn as_socket(&self) -> usize {
        return self.as_raw_fd() as usize;
    }
    
    #[cfg(windows)]
    fn as_socket(&self) -> usize {
        return self.as_raw_socket() as usize;
    }
}

