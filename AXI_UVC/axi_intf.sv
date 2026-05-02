interface axi_intf(input logic aclk, input logic arst_n);

//write address channel
logic [`ADDR_WIDTH-1:0] awaddr;
logic [3:0] awid;
logic [3:0] awlen;
logic [2:0] awsize;	
burst_type_t awburst;
lock_type_t awlock;
logic awready;
logic awvalid;
logic [2:0] awprot;
logic [3:0] awcache;

//write data channel
logic [3:0] wid;
logic [`DATA_BUS_WIDTH-1:0] wdata;
logic wready;
logic wvalid;
logic [3:0] wstrb;
logic wlast;

//write response channel
logic [3:0] bid;
logic bready;
logic bvalid;
resp_t bresp;

//read address channel
logic [`ADDR_WIDTH-1:0] araddr;
logic [3:0] arid;
logic [3:0] arlen;
logic [2:0] arsize;
burst_type_t arburst;
lock_type_t arlock;
logic arready;
logic arvalid;
logic [2:0] arprot;
logic [3:0] arcache;


//read data and resp channel
logic [3:0] rid;
logic [`DATA_BUS_WIDTH-1:0] rdata;
logic rlast;
logic rready;
logic rvalid;
resp_t rresp;

clocking drv_cb @(posedge aclk);
default input #1 output #0;
input aclk, arst_n;
output awaddr, awid, awburst, awsize, awlen, awvalid, awlock, awprot, awcache;
input awready;
output wdata, wvalid, wlast, wid, wstrb;
input wready;
output bready;
input bresp, bvalid, bid;
output araddr, arid, arburst, arsize, arlen, arvalid, arlock, arprot, arcache;
input arready;
output rready;
input rdata, rlast, rresp, rvalid, rid;
endclocking

clocking resp_cb @(posedge aclk);
default input #0 output #1;
input aclk, arst_n;
input awaddr, awid, awburst, awsize, awlen, awvalid, awlock, awprot, awcache;
output awready;
input wdata, wvalid, wlast, wid, wstrb;
output wready;
input bready;
output bresp, bvalid, bid;
input araddr, arid, arburst, arsize, arlen, arvalid, arlock, arprot, arcache;
output arready;
input rready;
output rdata, rlast, rresp, rvalid, rid;
endclocking

clocking mon_cb @(posedge aclk);
default input #1 output #1;
input aclk, arst_n;
input awaddr, awid, awburst, awsize, awlen, awvalid, awlock, awprot, awcache;
input awready;
input wdata, wvalid, wlast, wid, wstrb;
input wready;
input bready;
input bresp, bvalid, bid;
input araddr, arid, arburst, arsize, arlen, arvalid, arlock, arprot, arcache;
input arready;
input rready;
input rdata, rlast, rresp, rvalid, rid;
endclocking

modport drv_mp (clocking drv_cb);
modport resp_mp (clocking resp_cb);
modport mon_mp (clocking mon_cb);

//assert property(@(posedge aclk) awvalid |-> ##[0:1] awready);
//cover property(@(posedge aclk) awvalid |-> ##[0:1] awready);

endinterface
