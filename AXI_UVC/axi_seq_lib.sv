class axi_base_seq extends uvm_sequence #(axi_tx);
`uvm_object_utils(axi_base_seq)
axi_tx tx;
`NEW_OBJ
uvm_phase phase;

task pre_body();
	phase = get_starting_phase();
	if(phase!=null) begin
		phase.raise_objection(this);
		phase.phase_done.set_drain_time(this,100);
	end
endtask

task post_body();
	if(phase!=null) phase.drop_objection(this);
endtask

endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class wr_seq extends axi_base_seq;
`uvm_object_utils(wr_seq)
`NEW_OBJ

task body();
repeat(axi_common::total_tx) begin
	`uvm_do_with(req, {req.wr_rd==1; req.len==5;})
end
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class rd_seq extends axi_base_seq;
`uvm_object_utils(rd_seq)
`NEW_OBJ

task body();
repeat(axi_common::total_tx) begin
	`uvm_do_with(req, {req.wr_rd==0;}) 
end
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class wr_rd_seq extends axi_base_seq;
`uvm_object_utils(wr_rd_seq)
`NEW_OBJ

task body();
repeat(axi_common::total_tx) begin
	`uvm_do_with(req, {req.wr_rd==1;})
	tx = new req;  // its a shallow copy
	`uvm_do_with(req, {req.wr_rd == 1'b0;
						req.addr == tx.addr;
						req.size == tx.size;
						req.len ==  tx.len;
						req.burst== tx.burst;
						req.lock == tx.lock;
						req.id == tx.id;
						})
end
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////
