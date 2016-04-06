use {ThreadUtils, LuaEngine};
pub struct CommandMgr;

static COMMAND_POOL_NAME : &'static str = "command";

impl CommandMgr {
    pub fn start_command_input() {
        let pool = ThreadUtils::instance().get_pool(&COMMAND_POOL_NAME.to_string());
        pool.execute(move || {
            loop {
                let mut line = String::new();
                let _ = unwrap_or!(::std::io::stdin().read_line(&mut line).ok(), 0);
                if line.is_empty() {
                    continue;
                }
                let line = line.trim_matches(|c| c == '\r' || c == '\n').to_string();
                if line == "quit" {
                    break;
                }
                let line = LuaEngine::convert_excute_string(line);
                LuaEngine::instance().apply_exec_string(line);
            }
        });
    }
}