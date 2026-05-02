class axi_base_test extends uvm_test;
`uvm_component_utils(axi_base_test)
`NEW_COMP
axi_env env;

function void build_phase (uvm_phase phase);
	super.build_phase(phase);
	env = axi_env::type_id::create("env", this);
endfunction

function void end_of_elaboration_phase(uvm_phase phase);
	super.end_of_elaboration_phase(phase);
	uvm_top.print_topology();
endfunction

function void report_phase(uvm_phase phase);
	super.report_phase(phase);
	if(axi_common::num_mis_match == 0) begin
		`uvm_info("AXI_TEST_LIB Status",$sformatf("%s Test Passed",get_type_name()),UVM_LOW)
	end
	else begin
		`uvm_info("AXI_TEST_LIB Status",$sformatf("%s Test Failed, Num_matches=%0d, Num_Mis_matches=%0d",get_type_name(),axi_common::num_match,axi_common::num_mis_match),UVM_LOW)
	end
endfunction

endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class wr_test extends axi_base_test;
`uvm_component_utils(wr_test)
`NEW_COMP
wr_seq seq;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	//uvm_config_db #(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", wr_rd_seq::get_type());
endfunction

task run_phase (uvm_phase phase);
	super.run_phase(phase);

	seq = wr_seq::type_id::create("seq");
	phase.raise_objection(this);
	phase.phase_done.set_drain_time(this,100);
	seq.start(env.magent.sqr);
	phase.drop_objection(this);
	
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class rd_test extends axi_base_test;
`uvm_component_utils(rd_test)
`NEW_COMP
rd_seq seq;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	// uvm_config_db #(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", wr_rd_seq::get_type());
endfunction

task run_phase (uvm_phase phase);
	super.run_phase(phase);

	seq = rd_seq::type_id::create("seq");
	phase.raise_objection(this);
	phase.phase_done.set_drain_time(this,100);
	seq.start(env.magent.sqr);
	phase.drop_objection(this);
	
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

class wr_rd_test extends axi_base_test;
`uvm_component_utils(wr_rd_test)
`NEW_COMP
wr_rd_seq seq;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	// uvm_config_db #(uvm_object_wrapper)::set(this, "env.magent.sqr.run_phase", "default_sequence", wr_rd_seq::get_type());
endfunction

task run_phase (uvm_phase phase);
	super.run_phase(phase);

	seq = wr_rd_seq::type_id::create("seq");
	phase.raise_objection(this);
	phase.phase_done.set_drain_time(this,100);
	seq.start(env.magent.sqr);
	phase.drop_objection(this);
	
endtask
endclass

///////////////////////////////////////////////////////////////////////////////////////////////////////////

