//! Lightweight, event-driven WebSockets for Rust.


extern crate httparse;
extern crate sha1;
extern crate rand;
extern crate url;
#[cfg(feature="ssl")] extern crate openssl;
#[macro_use] extern crate log;
extern crate time;

mod handler;
mod result;
mod connection;
mod frame;
mod message;
mod handshake;
mod protocol;
mod stream;

#[cfg(feature="permessage-deflate")]
pub mod deflate;

pub use handler::Handler;

pub use result::{Result, Error};
pub use result::Kind as ErrorKind;
pub use message::Message;
pub use frame::Frame;
pub use protocol::{CloseCode, OpCode};
pub use handshake::{Handshake, Request, Response};
pub use connection::Connection;

use std::default::Default;

/// WebSocket settings
#[derive(Debug, Clone, Copy)]
pub struct Settings {
    /// The maximum number of connections that this WebSocket will support.
    /// The default setting is low and should be increased when expecting more
    /// connections because this is a hard limit and no new connections beyond
    /// this limit can be made until an old connection is dropped.
    /// Default: 100
    pub max_connections: usize,
    /// The number of events anticipated per connection. The event loop queue size will
    /// be `queue_size` * `max_connections`. In order to avoid an overflow error,
    /// `queue_size` * `max_connections` must be less than or equal to `usize::max_value()`.
    /// The queue is shared between connections, which means that a connection may schedule
    /// more events than `queue_size` provided that another connection is using less than
    /// `queue_size`. However, if the queue is maxed out a Queue error will occur.
    /// Default: 5
    pub queue_size: usize,
    /// Whether to panic when unable to establish a new TCP connection.
    /// Default: false
    pub panic_on_new_connection: bool,
    /// Whether to panic when a shutdown of the WebSocket is requested.
    /// Default: false
    pub panic_on_shutdown: bool,
    /// The maximum number of fragments the connection can handle without reallocating.
    /// Default: 10
    pub fragments_capacity: usize,
    /// Whether to reallocate when `fragments_capacity` is reached. If this is false,
    /// a Capacity error will be triggered instead.
    /// Default: true
    pub fragments_grow: bool,
    /// The maximum length of outgoing frames. Messages longer than this will be fragmented.
    /// Default: 65,535
    pub fragment_size: usize,
    /// The size of the incoming buffer. A larger buffer uses more memory but will allow for fewer
    /// reallocations.
    /// Default: 2048
    pub in_buffer_capacity: usize,
    /// Whether to reallocate the incoming buffer when `in_buffer_capacity` is reached. If this is
    /// false, a Capacity error will be triggered instead.
    /// Default: true
    pub in_buffer_grow: bool,
    /// The size of the outgoing buffer. A larger buffer uses more memory but will allow for fewer
    /// reallocations.
    /// Default: 2048
    pub out_buffer_capacity: usize,
    /// Whether to reallocate the incoming buffer when `out_buffer_capacity` is reached. If this is
    /// false, a Capacity error will be triggered instead.
    /// Default: true
    pub out_buffer_grow: bool,
    /// Whether to panic when an Internal error is encountered. Internal errors should generally
    /// not occur, so this setting defaults to true as a debug measure, whereas production
    /// applications should consider setting it to false.
    /// Default: true
    pub panic_on_internal: bool,
    /// Whether to panic when a Capacity error is encountered.
    /// Default: false
    pub panic_on_capacity: bool,
    /// Whether to panic when a Protocol error is encountered.
    /// Default: false
    pub panic_on_protocol: bool,
    /// Whether to panic when an Encoding error is encountered.
    /// Default: false
    pub panic_on_encoding: bool,
    /// Whether to panic when a Queue error is encountered.
    /// Default: false
    pub panic_on_queue: bool,
    /// Whether to panic when an Io error is encountered.
    /// Default: false
    pub panic_on_io: bool,
    /// Whether to panic when a Timer error is encountered.
    /// Default: false
    pub panic_on_timeout: bool,
    /// The WebSocket protocol requires frames sent from client endpoints to be masked as a
    /// security and sanity precaution. Enforcing this requirement, which may be removed at some
    /// point may cause incompatibilities. If you need the extra security, set this to true.
    /// Default: false
    pub masking_strict: bool,
    /// The WebSocket protocol requires clients to verify the key returned by a server to ensure
    /// that the server and all intermediaries can perform the protocol. Verifying the key will
    /// consume processing time and other resources with the benifit that we can fail the
    /// connection early. The default in WS-RS is to accept any key from the server and instead
    /// fail late if a protocol error occurs. Change this setting to enable key verification.
    /// Default: false
    pub key_strict: bool,
    /// The WebSocket protocol requires clients to perform an opening handshake using the HTTP
    /// GET method for the request. However, since only WebSockets are supported on the connection,
    /// verifying the method of handshake requests is not always necessary. To enforce the
    /// requirement that handshakes begin with a GET method, set this to true.
    /// Default: false
    pub method_strict: bool,
    /// Indicate whether server connections should use ssl encryption when accepting connections.
    /// Setting this to true means that clients should use the `wss` scheme to connect to this
    /// server. Note that using this flag will in general necessitate overriding the
    /// `Handler::build_ssl` method in order to provide the details of the ssl context. It may be
    /// simpler for most users to use a reverse proxy such as nginx to provide server side
    /// encryption.
    ///
    /// Default: false
    pub encrypt_server: bool,
}

impl Default for Settings {

    fn default() -> Settings {
        Settings {
            max_connections: 100,
            queue_size: 5,
            panic_on_new_connection: false,
            panic_on_shutdown: false,
            fragments_capacity: 10,
            fragments_grow: true,
            fragment_size: u16::max_value() as usize,
            in_buffer_capacity: 2048,
            in_buffer_grow: true,
            out_buffer_capacity: 2048,
            out_buffer_grow: true,
            panic_on_internal: true,
            panic_on_capacity: false,
            panic_on_protocol: false,
            panic_on_encoding: false,
            panic_on_queue: false,
            panic_on_io: false,
            panic_on_timeout: false,
            masking_strict: false,
            key_strict: false,
            method_strict: false,
            encrypt_server: false,
        }
    }
}

