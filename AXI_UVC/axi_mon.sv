class axi_mon extends uvm_monitor;
virtual axi_intf vif;
axi_tx wr_tx;
axi_tx rd_tx;
axi_tx reset_tx;
uvm_analysis_port#(axi_tx) ap_port;
`uvm_component_utils(axi_mon)
`NEW_COMP

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	if(!uvm_config_db#(virtual axi_intf)::get(this, "", "axi_intf", vif))
	`uvm_fatal("MONITOR","PIF not received");
	ap_port = new("ap_port", this);
endfunction

task run_phase(uvm_phase phase);
	super.run_phase(phase);
	forever begin
	@(vif.mon_cb);
	if(!vif.mon_cb.arst_n) begin
		monitor_reset();
		continue;
	end
	else begin
		if(vif.mon_cb.awvalid && vif.mon_cb.awready) begin
			wr_tx = axi_tx::type_id::create("wr_tx");
			wr_tx.wr_rd = 1'b1;
			wr_tx.addr = vif.mon_cb.awaddr;
			wr_tx.len = vif.mon_cb.awlen;
			wr_tx.size = vif.mon_cb.awsize;
			wr_tx.id = vif.mon_cb.awid;
			wr_tx.burst = vif.mon_cb.awburst;
			wr_tx.lock = vif.mon_cb.awlock;
		end

		if(vif.mon_cb.wvalid && vif.mon_cb.wready) begin
			if(wr_tx != null) begin
				wr_tx.dataQ.push_back(vif.mon_cb.wdata);
				wr_tx.strbQ.push_back(vif.mon_cb.wstrb);
			end
		end

		if(vif.mon_cb.bvalid && vif.mon_cb.bready) begin
			if(wr_tx != null) begin
				wr_tx.respQ.push_back(vif.mon_cb.bresp);
				ap_port.write(wr_tx);
				wr_tx = null;
			end
		end

		if(vif.mon_cb.arvalid && vif.mon_cb.arready) begin
			rd_tx = axi_tx::type_id::create("rd_tx");
			rd_tx.wr_rd = 1'b0;
			rd_tx.addr = vif.mon_cb.araddr;
			rd_tx.len = vif.mon_cb.arlen;
			rd_tx.size = vif.mon_cb.arsize;
			rd_tx.id = vif.mon_cb.arid;
			rd_tx.burst = vif.mon_cb.arburst;
			rd_tx.lock = vif.mon_cb.arlock;
		end

		if(vif.mon_cb.rvalid && vif.mon_cb.rready) begin
			if(rd_tx != null) begin
				rd_tx.dataQ.push_back(vif.mon_cb.rdata);
				rd_tx.respQ.push_back(vif.mon_cb.rresp);
				if(vif.mon_cb.rlast==1) begin
					ap_port.write(rd_tx);
					rd_tx = null;
				end
			end
		end
	end
	end
endtask

task monitor_reset();
	reset_tx = axi_tx::type_id::create("reset_tx");
	reset_tx.is_reset=1;
	ap_port.write(reset_tx);
	wr_tx = null;
	rd_tx = null;
endtask

endclass
