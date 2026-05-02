module axi_slave (
	axi_intf vif
);
axi_tx rd_tx;
axi_tx wr_tx;
reg [31:0] mem[*];

always @(vif.resp_cb) begin
		if(vif.resp_cb.awvalid==1) begin
			vif.resp_cb.awready<=1;
			wr_tx = new("wr_tx");
			wr_tx.id= vif.resp_cb.awid;
			wr_tx.addr= vif.resp_cb.awaddr;
			wr_tx.len= vif.resp_cb.awlen;
			wr_tx.size= vif.resp_cb.awsize;
			wr_tx.burst= vif.resp_cb.awburst;
		end
		else begin
			vif.resp_cb.awready <=0;
		end
		////////////////////////////////////////////
		if(vif.resp_cb.wvalid==1) begin
			vif.resp_cb.wready<=1;
			mem[wr_tx.addr] = vif.resp_cb.wdata;
			wr_tx.addr += 2**wr_tx.size;	
			if(vif.resp_cb.wlast==1) begin
				write_resp_phase(vif.resp_cb.wid);
			end
		end
		else begin
			vif.resp_cb.wready<=0;
		end
		///////////////////////////////////////////// 
		if(vif.resp_cb.arvalid==1) begin
			vif.resp_cb.arready<=1;
			rd_tx = new("rd_tx");
			rd_tx.id = vif.resp_cb.arid;
			rd_tx.addr = vif.resp_cb.araddr;
			rd_tx.len = vif.resp_cb.arlen;
			rd_tx.size = vif.resp_cb.arsize;
			rd_tx.burst = vif.resp_cb.arburst;
			read_data_phase(vif.resp_cb.arid);
		end
		else begin
			vif.resp_cb.arready <=0;
		end
end

task write_resp_phase(bit [3:0] id);
	vif.resp_cb.bid <= id;
	vif.resp_cb.bresp <= OKAY;
	vif.resp_cb.bvalid <=1;
	wait(vif.resp_cb.bready ==1);	
	@(vif.resp_cb);
	vif.resp_cb.bid <= 0;
	vif.resp_cb.bresp <= 0;
	vif.resp_cb.bvalid <=0;
endtask

task read_data_phase(bit [3:0] id);
	for(int i=0; i<=rd_tx.len; i++) begin
		@(vif.resp_cb);
		vif.resp_cb.rdata <= mem[rd_tx.addr];
		rd_tx.addr += 2**rd_tx.size;
		vif.resp_cb.rid <= id;
		vif.resp_cb.rresp <= OKAY;
		vif.resp_cb.rlast <= (i==rd_tx.len);
		vif.resp_cb.rvalid <= 1;
		wait(vif.resp_cb.rready==1);
	end
	read_data_reset();
endtask

task read_data_reset();
	@(vif.resp_cb);
	vif.resp_cb.rdata <=0;
	vif.resp_cb.rid <=0;
	vif.resp_cb.rlast<=0;
	vif.resp_cb.rvalid<=0;
endtask

endmodule

