class axi_tx extends uvm_sequence_item;
	bit is_reset;
rand bit wr_rd;
rand bit [`ADDR_WIDTH-1:0] addr;
	 bit [`ADDR_WIDTH-1:0] wrap_lower_addr;
	 bit [`ADDR_WIDTH-1:0] wrap_upper_addr;
	 int tx_size;
rand bit [3:0] id;
rand bit [3:0] len;
rand bit [2:0] size;
rand burst_type_t burst;
rand lock_type_t lock;
rand bit [2:0] prot;
rand bit [3:0] cache;

rand bit [`DATA_BUS_WIDTH-1:0] dataQ[$];
rand bit [(`DATA_BUS_WIDTH/8)-1:0] strbQ[$];
	 resp_t respQ[$];



`uvm_object_utils_begin(axi_tx)
	`uvm_field_int(wr_rd, UVM_ALL_ON)
	`uvm_field_int(addr, UVM_ALL_ON)
	`uvm_field_int(id, UVM_ALL_ON)
	`uvm_field_int(len, UVM_ALL_ON)
	`uvm_field_int(size, UVM_ALL_ON)
	`uvm_field_enum(burst_type_t, burst, UVM_ALL_ON)
	`uvm_field_enum(lock_type_t, lock, UVM_ALL_ON)
	`uvm_field_queue_int(dataQ, UVM_ALL_ON)
	`uvm_field_queue_int(strbQ, UVM_ALL_ON)
	`uvm_field_queue_enum(resp_t, respQ, UVM_ALL_ON)
`uvm_object_utils_end
`NEW_OBJ

function void cal_wrap_range();
if(burst == WRAP) begin
	tx_size = (len+1)*(2**size);
	wrap_lower_addr = addr - (addr%tx_size);
	wrap_upper_addr = wrap_lower_addr + tx_size-1;
	$display("addr=%0h",addr);
	$display("wrap_lower_addr=%0h",wrap_lower_addr);
	$display("wrap_upper_addr=%0h",wrap_upper_addr);
end
endfunction

function void check_wrap();
if(burst == WRAP) begin
	addr = wrap_lower_addr + 
       ((addr - wrap_lower_addr) % tx_size);	
end
endfunction

function void post_randomize();
int bytes_per_transfer;
int strb_starting_bit;
bit [`STRB_SIZE-1:0] mask;

if(wr_rd==0) axi_common::total_beats += len+1;

  bytes_per_transfer = (1 << size);
  strb_starting_bit  = addr % `STRB_SIZE;

  foreach (strbQ[i]) begin
    strbQ[i] = 0;
    mask = ((1 << bytes_per_transfer) - 1) << strb_starting_bit;
    strbQ[i] = mask;
    strb_starting_bit += bytes_per_transfer;
    if (strb_starting_bit >= `STRB_SIZE)
      strb_starting_bit = 0;
  end
endfunction

constraint rsvd_c {
	burst != 2'b11;
	lock != 2'b11;
}

constraint burst_c {
	burst dist { FIXED := 2,
				 INCR := 3,
				 WRAP := 3} ;
}

constraint wrap_c {
	(burst==WRAP) -> (len inside {1,3,7,15} && (addr%(2**size)==0));
}

constraint dataQ_c {
	dataQ.size() == len+1;
	strbQ.size() == len+1;
}

constraint size_c {
  (1 << size) <= `STRB_SIZE;
}

constraint align_c {
  addr % (1 << size) == 0;
}

endclass
