class axi_env extends uvm_env;
`uvm_component_utils(axi_env)
`NEW_COMP
axi_magent magent;
axi_sagent sagent;
axi_sbd sbd;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	magent = axi_magent::type_id::create("magent", this);
	sagent = axi_sagent::type_id::create("sagent", this);
	sbd = axi_sbd::type_id::create("sbd", this);
endfunction

function void connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	magent.mon.ap_port.connect(sbd.ap_imp);
endfunction

endclass
