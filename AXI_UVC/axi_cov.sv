class axi_cov extends uvm_subscriber#(axi_tx);
axi_tx tx;
`uvm_component_utils(axi_cov)

covergroup axi_cg;
	WR_RD_CP : coverpoint tx.wr_rd {
		bins WRITE = {1'b1};
		bins READ = {1'b0};
	}

	ADDR_CP : coverpoint tx.addr {
		option.auto_bin_max = 10;
	}

	LEN_CP : coverpoint tx.len {
		option.auto_bin_max = 16;
	}

	SIZE_CP : coverpoint tx.size {
		bins ONE_BYTE = {3'b000};
		bins TWO_BYTE = {3'b001};
		bins FOUR_BYTE = {3'b010};
		bins EIGHT_BYTE = {3'b011};
		bins SIXTEEN_BYTE = {3'b100};
		bins THIRTY_TWO_BYTE = {3'b101};
		bins SIXTY_FOUR_BYTE = {3'b110};
		bins ONE_TWENTY_EIGHT_BYTE = {3'b111};
	}
	
	BURST_CP : coverpoint tx.burst {
		bins FIXED = {2'b00};
		bins INCR = {2'b01};
		bins WRAP = {2'b10};
		bins RSVD_BURST = default ;
	}
	
	LOCK_CP : coverpoint tx.lock {
		bins NORMAL = {2'b00};
		bins EXCLUSIVE = {2'b01};
		bins LOCKED = {2'b10};
		bins RSVD_LOCK = default ;
	}
	
	RESP_CP : coverpoint tx.respQ[0] {
		bins OKAY = {2'b00};
		bins EXOKAY = {2'b01};
		bins SLVERR = {2'b10};
		bins DECERR = {2'b11} ;
	}

	ID_CP : coverpoint tx.id {
		option.auto_bin_max = 16;
	}
/*
	STRB_CP : coverpoint tx.strbQ iff(tx.wr_rd) {
		bins one_byte[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
 		bins two_byte[] = {4'b0011, 4'b1100};
  		bins four_byte  = {4'b1111};
		illegal_bins zero = {4'b0};
	} */

	cross WR_RD_CP, ADDR_CP;

endgroup

function new(string name="", uvm_component parent=null);
	super.new(name, parent);
	axi_cg = new();
endfunction

function void write(T t);
	$cast(tx, t);
	axi_cg.sample();
endfunction

endclass
