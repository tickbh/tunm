extern crate pkg_config;
extern crate gcc;

fn main() {
    match pkg_config::find_library("lua5.2") {
        Ok(_) => return,
        Err(..) => {}
    };

    gcc::Config::new()
        .file("cjson/fpconv.c")
        .file("cjson/lua_cjson.c")
        .file("cjson/strbuf.c")
        .include("cjson")
        .include("include")
        .compile("libluaext.a");
}
