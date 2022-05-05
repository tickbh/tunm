use std::io;
use std::net::SocketAddr;
use std::net::TcpStream;

use std::io::Cursor;
use std::io::{Read, Write};
#[cfg(feature="ssl")]
use openssl::ssl::SslStream;
#[cfg(feature="ssl")]
use openssl::ssl::error::Error as SslError;

use result::{Result, Error, Kind};

use self::Stream::*;
pub enum Stream {
    Tcp(TcpStream),
    #[cfg(feature="ssl")]
    Tls {
        sock: SslStream<TcpStream>,
        negotiating: bool,
    }
}


impl Stream {

    pub fn tcp(stream: TcpStream) -> Stream {
        Tcp(stream)
    }

    #[cfg(feature="ssl")]
    pub fn tls(stream: SslStream<TcpStream>) -> Stream {
        Tls { sock: stream, negotiating: false }
    }

    #[cfg(feature="ssl")]
    pub fn is_tls(&self) -> bool {
        match *self {
            Tcp(_) => false,
            Tls {..} => true,
        }
    }

    pub fn evented(&self) -> &TcpStream {
        match *self {
            Tcp(ref sock) => sock,
            #[cfg(feature="ssl")]
            Tls { ref sock, ..} => sock.get_ref(),
        }
    }

    pub fn is_negotiating(&self) -> bool {
        match *self {
            Tcp(_) => false,
            #[cfg(feature="ssl")]
            Tls { sock: _, ref negotiating } => *negotiating,
        }

    }

    pub fn clear_negotiating(&mut self) -> Result<()> {
        match *self {
            Tcp(_) => Err(Error::new(Kind::Internal, "Attempted to clear negotiating flag on non ssl connection.")),
            #[cfg(feature="ssl")]
            Tls { sock: _, ref mut negotiating } => Ok(*negotiating = false),
        }
    }

    pub fn peer_addr(&self) -> io::Result<SocketAddr> {
        match *self {
            Tcp(ref sock) => sock.peer_addr(),
            #[cfg(feature="ssl")]
            Tls { ref sock, ..} => sock.get_ref().peer_addr(),
        }
    }

    pub fn local_addr(&self) -> io::Result<SocketAddr> {
        match *self {
            Tcp(ref sock) => sock.local_addr(),
            #[cfg(feature="ssl")]
            Tls { ref sock, ..} => sock.get_ref().local_addr(),
        }
    }

    pub fn do_write_buf(&mut self, val: &mut Cursor<Vec<u8>>) -> Result<usize> {
        let len = try!(self.write(val.get_mut()));
        if len != val.get_mut().len() as usize {
            return Err(Error::new(Kind::OutNotEnough, "Write Not Enough"));
        }
        Ok(len)
    }

    // pub fn do_read_buf(&mut self, val: &mut Cursor<Vec<u8>>) -> Result<usize> {
    //     let position = val.position();
    //     let mut buffer = vec![0; 10240];
    //     let len = try!(self.read(&mut buffer[..]));
    //     let _ = try!(val.write(&buffer[..len]));
    //     val.set_position(position);
    //     Ok(len)
    // }
}

impl Read for Stream {

    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        match *self {
            Tcp(ref mut sock) => sock.read(buf),
            #[cfg(feature="ssl")]
            Tls { ref mut sock, ref mut negotiating } => {
                match sock.ssl_read(buf) {
                    Ok(cnt) => Ok(Some(cnt)),
                    Err(SslError::WantWrite(_)) => {
                        *negotiating = true;
                        Ok(0)
                    },
                    Err(SslError::WantRead(_)) => Ok(0),
                    Err(err) =>
                        Err(io::Error::new(io::ErrorKind::Other, err)),
                }
            }
        }
    }
}

impl Write for Stream {

    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        match *self {
            Tcp(ref mut sock) => sock.write(buf),
            #[cfg(feature="ssl")]
            Tls { ref mut sock, ref mut negotiating } => {

                *negotiating = false;

                match sock.ssl_write(buf) {
                    Ok(cnt) => Ok(cnt),
                    Err(SslError::WantRead(_)) => {
                        *negotiating = true;
                        Ok(0)
                    },
                    Err(SslError::WantWrite(_)) => Ok(0),
                    Err(err) =>
                        Err(io::Error::new(io::ErrorKind::Other, err)),
                }
            }
        }
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
