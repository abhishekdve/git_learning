class axi_sagent extends uvm_agent;
`uvm_component_utils(axi_sagent)
`NEW_COMP
axi_responder responder;
axi_mon mon;

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	responder = axi_responder::type_id::create("responder", this);
	mon = axi_mon::type_id::create("mon",this);
endfunction

endclass
