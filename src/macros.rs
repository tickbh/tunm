#![macro_use]

macro_rules! fail {
    ($expr:expr) => (
        return Err(::std::convert::From::from($expr));
    )
}

macro_rules! ensure {
    ($expr:expr, $err_result:expr) => (
        if !($expr) { fail!($err_result) }
    )
}

macro_rules! unwrap_or {
    ($expr:expr, $or:expr) => (
        match $expr {
            Some(x) => x,
            None => { $or }
        }
    )
}

#[macro_export]
macro_rules! raw_to_ref {
    ($expr:expr) => (unsafe { &mut *$expr})
}
