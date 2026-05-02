`define ADDR_WIDTH 32
`define DATA_BUS_WIDTH 32
`define STRB_SIZE (`DATA_BUS_WIDTH/8)
`define NEW_OBJ \
function new(string name=""); \
	super.new(name); \
endfunction

`define NEW_COMP \
function new(string name="", uvm_component parent=null); \
	super.new(name, parent); \
endfunction

typedef enum bit [1:0]{
	OKAY,
	EXOKAY,
	SLVERR,
	DECERR
}resp_t;

typedef enum bit [1:0] {
	NORMAL,
	EXCLUSIVE,
	LOCKED,
	RES_LOCK
} lock_type_t;

typedef enum bit [1:0] {
	FIXED,
	INCR,
	WRAP,
	RES_BURST
} burst_type_t;

class axi_common;
static int total_tx=4;
static int num_match;
static int num_mis_match;
static int total_beats;
endclass
