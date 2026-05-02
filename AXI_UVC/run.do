vlib work
vlog  -cover fcbest +cover +incdir+./src axi_tb.sv    +acc
vsim -coverage -voptargs="+acc" tb -sv_lib "C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi" +UVM_TESTNAME=wr_rd_test -l run.log 
#add wave -r /*
add wave sim:/tb/pif/*
run -all
coverage save vsim.ucdb
# vcover report vsim.ucdb
