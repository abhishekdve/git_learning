class axi_responder extends uvm_component;
virtual axi_intf vif;
bit [`DATA_BUS_WIDTH-1:0] wr_beat;
bit [`DATA_BUS_WIDTH-1:0] rd_beat;

reg [7:0] mem[*];
reg [7:0] fifo[*][$];
axi_tx wa[*];
axi_tx ra[*];
`uvm_component_utils(axi_responder)
`NEW_COMP

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	if(!uvm_config_db#(virtual axi_intf)::get(this, "", "axi_intf", vif))
	`uvm_fatal("RESPONDER", "PIF not received");
endfunction

task run_phase(uvm_phase phase);
super.run_phase(phase);
forever begin
	@(vif.resp_cb);
	if(!vif.resp_cb.arst_n) begin
		reset_responder();
		continue;
	end
	else begin
		if(vif.resp_cb.awvalid==1) begin
			vif.resp_cb.awready<=1;
			wa[vif.resp_cb.awid] = new();
			wa[vif.resp_cb.awid].id= vif.resp_cb.awid;
			wa[vif.resp_cb.awid].addr= vif.resp_cb.awaddr;
			wa[vif.resp_cb.awid].len= vif.resp_cb.awlen;
			wa[vif.resp_cb.awid].size= vif.resp_cb.awsize;
			wa[vif.resp_cb.awid].burst= vif.resp_cb.awburst;
			wa[vif.resp_cb.awid].cal_wrap_range();
		end
		else begin
			vif.resp_cb.awready <=0;
		end

		if(vif.resp_cb.wvalid==1) begin
			vif.resp_cb.wready<=1;
			if(!wa.exists(vif.resp_cb.wid)) begin
				`uvm_error("AXI_RESPONDER", $sformatf("Write request for ID %0d does not exist", vif.resp_cb.wid))
				vif.resp_cb.wready <= 0;
			end
			else begin
				if(wa[vif.resp_cb.wid].burst inside {WRAP, INCR}) begin
				bit [`ADDR_WIDTH-1:0] addr = (wa[vif.resp_cb.wid].addr/`STRB_SIZE)*`STRB_SIZE; //addr offset
					for(int a=0; a<`STRB_SIZE; a++) begin 
						if(vif.resp_cb.wstrb[a]) begin
							mem[addr+a] = vif.resp_cb.wdata[8*a +: 8];
							`uvm_info("AXI_RESPONDER", $sformatf("Write Data at addr %0h=%0h",(addr+a),mem[addr+a]),UVM_LOW)
						end
					end
					wa[vif.resp_cb.wid].addr += 2**wa[vif.resp_cb.wid].size;
					wa[vif.resp_cb.wid].check_wrap();
				end

				else begin
					if(wa[vif.resp_cb.wid].burst==FIXED) begin
						wr_beat = vif.resp_cb.wdata;
					for(int a=0; a<`STRB_SIZE; a++) begin
						if(vif.resp_cb.wstrb[a]) begin
							fifo[wa[vif.resp_cb.wid].addr].push_back(wr_beat[8*a +: 8]);
						end
					end
						`uvm_info("AXI_RESPONDER", $sformatf("Write Data at addr %0h=%0h",wa[vif.resp_cb.wid].addr,wr_beat),UVM_LOW)
					end
					else begin
						$display("ERROR- WRITE RSVD BURST");
					end				
				end
				if(vif.resp_cb.wlast==1) begin
					write_resp_phase(vif.resp_cb.wid);
				end
			end
		end
		else begin
			vif.resp_cb.wready<=0;
		end
		 
		if(vif.resp_cb.arvalid==1) begin
			vif.resp_cb.arready<=1;
			ra[vif.resp_cb.arid] = new();
			ra[vif.resp_cb.arid].id = vif.resp_cb.arid;
			ra[vif.resp_cb.arid].addr = vif.resp_cb.araddr;
			ra[vif.resp_cb.arid].len = vif.resp_cb.arlen;
			ra[vif.resp_cb.arid].size = vif.resp_cb.arsize;
			ra[vif.resp_cb.arid].burst = vif.resp_cb.arburst;
			ra[vif.resp_cb.arid].cal_wrap_range();
			read_data_phase(vif.resp_cb.arid);
		end
		else begin
			vif.resp_cb.arready <=0;
		end
	end
end
endtask

task write_resp_phase(bit [3:0] id);
	vif.resp_cb.bid <= id;
	vif.resp_cb.bresp <= OKAY;
	vif.resp_cb.bvalid <=1;
	wait(vif.resp_cb.bready ==1);	
	@(vif.resp_cb);
	wa.delete(id);
	vif.resp_cb.bid <= 0;
	vif.resp_cb.bvalid <=0;
endtask

task read_data_phase(bit [3:0] id);
	if(!ra.exists(id)) begin
		`uvm_error("AXI_RESPONDER", $sformatf("Read request for ID %0d does not exist", id))
		return;
	end
	for(int i=0; i<=ra[id].len; i++) begin
		@(vif.resp_cb);
		if(ra[id].burst inside {WRAP, INCR}) begin
			bit [`ADDR_WIDTH-1:0] addr = (ra[id].addr/`STRB_SIZE)*`STRB_SIZE; //addr offset
			int start_lane = ra[id].addr%`STRB_SIZE;
				for(int a=0; a<`STRB_SIZE; a++) begin 
					if(a>=start_lane && a< start_lane + (1<<ra[id].size)) begin
						rd_beat[8*a +: 8] = mem[addr+a];
						`uvm_info("AXI_RESPONDER", $sformatf("Read Data at addr %0h=%0h",(addr+a),mem[addr+a]),UVM_LOW)
					end
				end
			vif.resp_cb.rdata <= rd_beat;
			`uvm_info("AXI_RESPONDER", $sformatf("Read Data at addr %0h=%0h",addr,rd_beat),UVM_LOW)
			rd_beat = 0;
			ra[id].addr += 2**ra[id].size;
			ra[id].check_wrap();
		end
		else begin
			if(ra[id].burst==FIXED) begin
				int start_lane = ra[id].addr%`STRB_SIZE;
				for(int a=0; a<`STRB_SIZE; a++) begin 
					if(a>=start_lane && a< start_lane + (1<<ra[id].size)) begin
						rd_beat[8*a +: 8] = fifo[ra[id].addr].pop_front();
					end
				end
				vif.resp_cb.rdata <= rd_beat;
				`uvm_info("AXI_RESPONDER", $sformatf("Read Data at addr %0h=%0h",ra[id].addr,rd_beat),UVM_LOW)
			end
			else begin
				$display("ERROR- READ RSVD BURST");
			end				
		end
		vif.resp_cb.rid <= id;
		vif.resp_cb.rresp <= OKAY;
		vif.resp_cb.rlast <= (i==ra[id].len);
		vif.resp_cb.rvalid <= 1;
		wait(vif.resp_cb.rready==1);
	end
	ra.delete(id);
	read_data_reset();
endtask

task read_data_reset();
	@(vif.resp_cb);
	vif.resp_cb.rdata <=0;
	vif.resp_cb.rid <=0;
	vif.resp_cb.rlast<=0;
	vif.resp_cb.rvalid<=0;
endtask

task reset_responder();
	vif.resp_cb.awready <= 0;
	vif.resp_cb.wready  <= 0;
	vif.resp_cb.arready <= 0;

	vif.resp_cb.bvalid  <= 0;
	vif.resp_cb.bid     <= 0;
	vif.resp_cb.bresp   <= OKAY;

	vif.resp_cb.rvalid  <= 0;
	vif.resp_cb.rlast   <= 0;
	vif.resp_cb.rid     <= 0;
	vif.resp_cb.rdata   <= 0;
	vif.resp_cb.rresp   <= OKAY;

	wa.delete();
	ra.delete();
	fifo.delete();
	mem.delete();	
endtask

endclass
