class axi_sbd extends uvm_scoreboard;
`NEW_COMP
`uvm_component_utils(axi_sbd)
uvm_analysis_imp#(axi_tx, axi_sbd) ap_imp;
byte mem[*];
byte fifo[*][$];

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	ap_imp = new("ap_imp",this);
endfunction

function void write(axi_tx tx);
if(tx.is_reset) begin
	mem.delete();
	fifo.delete();
	return;
end
else begin
	if(tx.wr_rd) begin
		if(tx.burst inside {WRAP,INCR}) begin
			bit [`ADDR_WIDTH-1:0] beat_addr;
			tx.cal_wrap_range();
			foreach(tx.dataQ[i]) begin
			  beat_addr = (tx.addr / `STRB_SIZE) * `STRB_SIZE;
				for(int a=0; a<`STRB_SIZE; a++) begin
					if(tx.strbQ[i][a]) begin
						mem[beat_addr+a] = tx.dataQ[i][8*a +: 8];
					end
				end
				tx.addr += (1<<tx.size);
				tx.check_wrap();
			end
		end
		else if(tx.burst==FIXED) begin
			foreach(tx.dataQ[i]) begin
				for(int a=0; a<`STRB_SIZE; a++) begin
					if(tx.strbQ[i][a]) begin
						fifo[tx.addr].push_back(tx.dataQ[i][8*a +: 8]);
					end
				end	
			end
		end
	end
	else begin
		bit match=1;
		if(tx.burst inside {WRAP, INCR}) begin
			int size = (1 << tx.size);
			int start_byte;
			start_byte = tx.addr % `STRB_SIZE;
			tx.cal_wrap_range();
			foreach(tx.dataQ[i]) begin
				start_byte = tx.addr % `STRB_SIZE;
				for (int a = 0; a <size; a++) begin
				  	int current_byte;
				  	current_byte = start_byte + a;
  				  	if(!mem.exists(tx.addr + a) || mem[tx.addr + a] != tx.dataQ[i][8*current_byte +: 8]) match =0;
				end
				tx.addr += (1<<tx.size);
				tx.check_wrap();
			end	
		end
		else if(tx.burst==FIXED) begin
			foreach(tx.dataQ[i]) begin
				int start_lane = tx.addr%`STRB_SIZE;
				for(int a=0; a<`STRB_SIZE; a++) begin 
					if(a>=start_lane && a< start_lane + (1<<tx.size)) begin
						if(!fifo.exists(tx.addr) || fifo[tx.addr].size() == 0) match = 0;
						else if(tx.dataQ[i][8*a +: 8] != fifo[tx.addr].pop_front()) match = 0;
					end
				end
			end
		end
		if (match) begin
    		axi_common::num_match++;
    		`uvm_info("AXI_SBD","The Tx. is Matching", UVM_LOW)
    	end
    	else begin
    		axi_common::num_mis_match++;
    		`uvm_info("AXI_SBD", "The Tx. is Not-Matching", UVM_LOW)
    	end
	end
end
endfunction

endclass
