extern crate mysql as my;
#[macro_use(raw_to_ref)]
extern crate tdengine;

use std::default::Default;

#[derive(Debug, PartialEq, Eq)]
struct Payment {
    customer_id: i32,
    amount: i32,
    account_name: Option<String>,
}

#[derive(Debug)]
struct Test {
    i : i32,
}

impl Drop for Test {
    fn drop(&mut self) {
        println!("ssssssssssssssssssssssss {:?}", self.i);
    }
}

fn main() {
    let first = Test { i : 32 };
    let raw = Box::into_raw(Box::new(first));
    // // let mut raw1 = unsafe { Box::from_raw(raw) };
    // let mut raw2 = unsafe { &mut *raw };
    // drop(raw2);
    // drop(first);
    // let mut raw3 = raw_to_ref!(raw);
    // println!("raw2 = {:?}", raw2);
    // raw2.i = 222;
    // println!("raw3 = {:?}", raw3);
    // drop(raw2);
    // raw1.i = 88;
    // drop(raw1);

    // let config = NetConfig::change_instance(" { \"customer_id\" : { \"index\" :    1, \"pattern\" : \"u16\" }, \
    //                                     \"amount\" : { \"index\" :    2, \"pattern\" : \"u16\" },  \
    //                                     \"account_name\" : { \"index\" :    3, \"pattern\" :\"str\" }   }",
    //     "{\"msg_db_result\"        : { \"index\" :    1, \"args\" : [ \"map[]\" ] }}");
    // let instance = NetConfig::instance() ;

    // let pool = my::Pool::new("mysql://root:123456@localhost:3306").unwrap();
    // let mut sql_db = tdengine::DbMysql::new(pool);
    // sql_db.execute(r"CREATE TEMPORARY TABLE tmp.payment (
    //                      customer_id int not null,
    //                      amount int not null,
    //                      account_name text
    //                  )").unwrap();

    // sql_db.execute(r"insert into tmp.payment (`customer_id`, `amount`, `account_name`) values(1, 2, 'myname')").unwrap();
    // let mut net_msg = NetMsg::new();
    // sql_db.select("SELECT customer_id, amount, account_name from tmp.payment", &mut net_msg);
    // net_msg.set_read_data();
    // let val = rt_proto::decode_proto(net_msg.get_buffer(), instance);
    // println!("val = {:?}", val);

    //     let _ = env_logger::init();
    // info!("can log from the test too");
    // sql_db.select("SELECT DATABASE()", &mut net_msg);

    // println!("\\b123");
    
    // // Let's create payment table.
    // // It is temporary so we do not need `tmp` database to exist.
    // // Unwap just to make sure no error happened.
    // pool.prep_exec(r"CREATE TEMPORARY TABLE tmp.payment (
    //                      customer_id int not null,
    //                      amount int not null,
    //                      account_name text
    //                  )", ()).unwrap();

    // let payments = vec![
    //     Payment { customer_id: 1, amount: 2, account_name: None },
    //     Payment { customer_id: 3, amount: 4, account_name: Some("foo".into()) },
    //     Payment { customer_id: 5, amount: 6, account_name: None },
    //     Payment { customer_id: 7, amount: 8, account_name: None },
    //     Payment { customer_id: 9, amount: 10, account_name: Some("bar".into()) },
    // ];

    // // Let's insert payments to the database
    // // We will use into_iter() because we do not need to map Stmt to anything else.
    // // Also we assume that no error happened in `prepare`.
    // for mut stmt in pool.prepare(r"INSERT INTO tmp.payment
    //                                    (customer_id, amount, account_name)
    //                                VALUES
    //                                    (?, ?, ?)").into_iter() {
    //     for p in payments.iter() {
    //         // `execute` takes ownership of `params` so we pass account name by reference.
    //         // Unwrap each result just to make sure no errors happended.
    //         stmt.execute((p.customer_id, p.amount, &p.account_name)).unwrap();
    //     }
    // }

    // // Let's select payments from database
    // let selected_payments: Vec<Payment> =
    // pool.prep_exec("SELECT customer_id, amount, account_name from tmp.payment", ())
    // .map(|result| { // In this closure we sill map `QueryResult` to `Vec<Payment>`
    //     // `QueryResult` is iterator over `MyResult<row, err>` so first call to `map`
    //     // will map each `MyResult` to contained `row` (no proper error handling)
    //     // and second call to `map` will map each `row` to `Payment`
    //     result.map(|x| x.unwrap()).map(|row| {
    //         let (customer_id, amount, account_name) = my::from_row(row);
    //         Payment {
    //             customer_id: customer_id,
    //             amount: amount,
    //             account_name: account_name,
    //         }
    //     }).collect() // Collect payments so now `QueryResult` is mapped to `Vec<Payment>`
    // }).unwrap(); // Unwrap `Vec<Payment>`

    // // Now make sure that `payments` equals to `selected_payments`.
    // // Mysql gives no guaranties on order of returned rows without `ORDER BY`
    // // so assume we are lukky.
    // assert_eq!(payments, selected_payments);
    // println!("Yay!");
}
