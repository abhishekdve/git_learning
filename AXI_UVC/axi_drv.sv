class axi_drv extends uvm_driver#(axi_tx);
`uvm_component_utils(axi_drv)
`NEW_COMP
virtual axi_intf vif;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	if(!uvm_config_db#(virtual axi_intf)::get(this, "", "axi_intf", vif))
	`uvm_fatal("AXI_DRIVER", "VIF is null")
endfunction

task run_phase(uvm_phase phase);
	super.run_phase(phase);
	forever begin
		@(posedge vif.aclk);
		if(!vif.arst_n) begin
			driver_reset();
		end
		else begin
			seq_item_port.get_next_item(req);
			drive_tx(req);
			seq_item_port.item_done();
		end
	end
endtask

task drive_tx(axi_tx tx);
	//fork
		if(tx.wr_rd) begin
			write_addr_phase(tx);
			write_data_phase(tx);
			write_resp_phase(tx);
		end
		else begin
			read_addr_phase(tx);
			read_data_phase(tx);
		end
//	join_none
endtask

task write_addr_phase(axi_tx tx);
	@(posedge vif.aclk);
	vif.awaddr <= tx.addr;
	vif.awid <= tx.id;
	vif.awburst <= tx.burst;
	vif.awlen <= tx.len;
	vif.awsize <= tx.size;
	vif.awlock <= tx.lock;
	vif.awvalid <= 1'b1;
	wait(vif.awready == 1);

	write_addr_reset();
endtask

task write_addr_reset();
	@(posedge vif.aclk);
	vif.awaddr <= 0;
	vif.awid <= 0;
	vif.awlen <= 0;
	vif.awsize <= 0;
	vif.awvalid <= 1'b0;	
endtask

task write_data_phase(axi_tx tx);
	for(int i=0; i<=tx.len; i++) begin
		@(posedge vif.aclk);
		vif.wdata <= tx.dataQ.pop_front();
		vif.wstrb <= tx.strbQ.pop_front();
		vif.wid <= tx.id;
		vif.wlast <= (i==tx.len);
		vif.wvalid <= 1'b1;
		wait(vif.wready);
	end
    @(posedge vif.aclk);
    vif.wvalid <= 1'b0;
	vif.wdata <= 1'b0;
    vif.wlast  <= 1'b0;
endtask


task write_resp_phase(axi_tx tx);
	while(!vif.bvalid) begin
		@(posedge vif.aclk);
	end
	vif.bready<=1'b1;
	@(posedge vif.aclk);
	vif.bready<=1'b0;
endtask

task read_addr_phase(axi_tx tx);
	@(posedge vif.aclk);
	vif.araddr <= tx.addr;
	vif.arid <= tx.id;
	vif.arburst <= tx.burst;
	vif.arlen <= tx.len;
	vif.arsize <= tx.size;
	vif.arlock <= tx.lock;
	vif.arvalid <= 1'b1;
	wait(vif.arready == 1);

	read_addr_reset();
endtask

task read_addr_reset();
	@(posedge vif.aclk);
	vif.araddr <= 0;
	vif.arid <= 0;
	vif.arlen <= 0;
	vif.arsize <= 0;
	vif.arvalid <= 1'b0;
endtask

task read_data_phase(axi_tx tx);
	for (int i = 0; i <= tx.len; i++) begin
		vif.rready <= 1'b1;
		do begin
			@(posedge vif.aclk);
		end while (!(vif.rvalid && vif.rready));
		vif.rready <= 1'b0;
	end
endtask

task driver_reset();
	vif.awid <= 0;	
	vif.awlen <= 0;	
	vif.awburst <= burst_type_t'(0);	
	vif.awsize <= 0;	
	vif.awprot <= 0;	
	vif.awcache <= 0;	
	vif.awlock <= lock_type_t'(0) ;	
	vif.awaddr <= 0;	
	vif.awvalid <= 0;
	
	
	vif.wdata <= 0;	
	vif.wvalid <= 0;	
	vif.wlast <= 0;	
	vif.wid <= 0;	
	vif.wstrb <= 0;

	vif.bready <=0;

	vif.arid <= 0;	
	vif.arlen <= 0;	
	vif.arburst <= burst_type_t'(0);	
	vif.arsize <= 0;	
	vif.arprot <= 0;	
	vif.arcache <= 0;	
	vif.arlock <= lock_type_t'(0);	
	vif.araddr <= 0;	
	vif.arvalid <= 0;
	
	vif.rready <=0;
endtask

endclass
