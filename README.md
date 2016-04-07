TDEngine
==========

a game server for rust + lua

[![Build Status](https://travis-ci.org/tickbh/tdengine.svg?branch=master)](https://travis-ci.org/tickbh/tdengine)


## How to run

```
git clone https://github.com/cloudwu/tdengine.git
cd tdengine
cargo build
```

##dependence
* redis server
* mysql server

and then modify config/Gate_GlobalConfig.conf and config/Client_GlobalConfig.conf to config your mysql db info, and redis db info

Run these in different console

```
cargo run --example serveres    # Launch first tdengine node  (Gate server) (default as the standalone option)
cargo run --example client    # Launch a client to connect server
```

## What is TDEngine?
An open source server engine, the clients and server communications can through the td_ptotocol.
Now only has the console client.

Engine framework written using Rust, game logic layer using Lua(Support the hotfix), 
developers do not need to re-implement some common server-side technology,
allows developers to concentrate on the game logic development, quickly create a variety of games.

(TDEngine is designed to be multi-process distributed dynamic load balancing scheme, 
in theory only need to expand hardware can increase load-limit, the single machine load-limit 
depends on complexity of logic of the game itself.)he game itself.)

## How To Use (Sorry, Only in Chinese now)

Read Wiki https://github.com/tickbh/tdengine/wiki
