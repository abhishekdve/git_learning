`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi_common.sv"
`include "axi_intf.sv"
`include "axi_tx.sv"
`include "axi_seq_lib.sv"
`include "axi_sqr.sv"
`include "axi_drv.sv"
`include "axi_mon.sv"
`include "axi_cov.sv"
`include "axi_magent.sv"
`include "axi_responder.sv"
`include "axi_slave.sv"
`include "axi_sagent.sv"
`include "axi_sbd.sv"
`include "axi_env.sv"
`include "axi_test_lib.sv"

module tb;
reg clk, rst;
axi_intf pif(clk, rst);

//axi_slave dut(pif.resp_mp);

initial begin
	clk = 0;
	forever #5 clk = ~clk;
end

initial begin
	uvm_config_db#(virtual axi_intf)::set(null, "*", "axi_intf", pif);
	rst =0;
	repeat(2)@(posedge clk);
	rst = 1;

end

initial begin
	run_test("wr_test");
end
endmodule
