\l hdb
\d .rdb

n_trades: 50000;
n_orders: 25000;

syms: `AAPL`MSFT`GOOGL`AMZN`TSLA`META`NVDA`JPM`BAC`WFC`GS`MS`V`MA`NFLX`DIS`PYPL`INTC`AMD`CRM`ORCL`CSCO`ADBE`QCOM`TXN`AVGO`IBM`NOW`UBER`LYFT`SQ`SNAP`TWTR`ZM`DOCU`ROKU`PINS`SHOP`SPOT`PLTR`COIN`HOOD`RBLX`ABNB`DASH`DDOG`SNOW`NET`CRWD`ZS;

sectors: `Tech`Tech`Tech`Tech`Tech`Tech`Tech`Finance`Finance`Finance`Finance`Finance`Finance`Finance`Tech`Media`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Tech`Crypto`Finance`Gaming`Travel`Tech`Tech`Tech`Tech`Tech`Tech;

basePrices: 185 420 175 185 250 500 880 195 35 58 450 95 280 470 700 110 75 45 160 300 125 52 580 175 190 1300 185 880 75 18 80 12 55 75 60 70 35 85 230 25 220 18 45 165 140 130 175 95 350 210f;

lotSizes: 50#100 200 500 1000;
t_syms: n_trades?syms;
t_base: basePrices[syms?t_syms];
t_mid: t_base * 1 + (n_trades?1.0) * 0.06 - 0.03;
t_dates: n_trades#(.z.D);
t_times: 09:30:00.000 + n_trades?23400000;
condList: `N`N`N`N`N,(`$"@"),`F`O`T;  

trades: ([]date: t_dates; time: t_times; sym: t_syms; price: t_mid + (n_trades?1.0) * 0.04 - 0.02; size: n_trades?(100 200 300 500 1000 2000 5000); side: n_trades?`B`S; exchange: n_trades?`NYSE`NASDAQ`BATS`ARCA; tradeId: `$"TRD-",/:string til n_trades; orderId: `$"ORD-",/:string n_trades?n_orders; condition: n_trades?condList; broker: n_trades?`GSCO`MSCO`JPMC`BOFA`CITI`BARC`UBS`CS);

\d .

gatewayQuery: {[s] rdb_output: select date,tradeId, time, sym,price, size,exchange,orderId,condition,broker, side from .rdb.trades where sym = s; hdb_output: select from trades where sym = s; :final_output:rdb_output,hdb_output}



