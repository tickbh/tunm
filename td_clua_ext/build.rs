extern crate pkg_config;
extern crate gcc;

fn main() {
    gcc::Config::new()
        .file("cjson/fpconv.c")
        .file("cjson/lua_cjson.c")
        .file("cjson/strbuf.c")
        .include("cjson")
        .include("include")
        .compile("libluaext.a");
}
