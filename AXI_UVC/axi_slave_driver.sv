class axi_slave_driver extends uvm_driver;
	`uvm_component_utils(axi_slave_driver)

	function new(string name ="", uvm_component parent=null);
	  super.new(name, parent);
	endfunction

	//virtual intf instance to get the intf data
	virtual axi_intf sif;

	function void build_phase(uvm_phase phase);
	  super.build_phase(phase);
	  if(!uvm_config_db#(virtual axi_intf)::get(this, "", "axi_intf", sif)) begin
		`uvm_fatal(get_full_name(), "unable to access the virtual axi_intf");
	  end
	endfunction

	//memory creations
	reg [7:0] mem[int];	//how many location we want that many location are created and also axi will have byte based transaction every byte have specific addr. 

	axi_tx wra[int];	//each transaction we have saperate id so,
				// id = 1 ---> addr = 4, len = 3, size = 2, lock, cache, prot etc
				// id = 2 ---> addr = 8, len = 7, size = 3, lock, cache, prot etc
	axi_tx rda[int];
	
	bit[7:0] id; 	//in write response logic we use this
	bit[7:0] temp_id;
	
	int beats; // no of beats supported by wrap transaction 2,4,8,16
	int k; //while calculating wrap boundary addr directly int value should be stored

	int wrap_boundary_addr;
	int upper_boundary_addr;

	bit[1:0] resp; //it is a temp var for bresp

	bit [31:0] wptr = 0;  //used in fixed write time because it will access the fifo type
	bit [31:0] rptr = 0;  //used in fixed read time because it will access the fifo type

	int cnt; //during all awsize comb in wrap and incr


	//now complete vip logic include in run_phase
	task run_phase(uvm_phase phase);
	  super.run_phase(phase);

	  forever begin
	    @(posedge sif.aclk);
	    if(sif.aresetn == 0) begin
		  sif.awready <= 0;
		  sif.wready <= 0;
		  sif.bvalid <= 1'b0;  
		  sif.bid <= 8'hxx;     //i take it as x
		//  sif.bresp <= 2'bxx;   //if it zero okay resp, so i'll put zero
		  sif.arready <= 0;
		  sif.rvalid <= 0;
		  sif.rid <= 8'hxx;
		  sif.rdata <= 0;
		 // sif.rresp <= 2'bxx;
		  sif.rlast <= 1'b0;

		 // for(int i=0; i<1000; i++) begin
		//	mem[i] = 8'h00;
		 // end
		end
		else begin
		  //------> for 5-different channel valid - ready hand shaking

		  //write addr channel(aw) 
		  if(sif.awvalid == 0) 		//master is not sending valid data
			  sif.awready <= 0;     //slave is not ready to receive data
		  
		  //write data channel(w)
	//	  if(sif.wvalid == 0) 		//master is not sending valid data
	//		  sif.wready <= 0;      //slave is not ready to receive data

		  //write response channel(b)	
		  if(sif.bready == 0)		//master is not ready to rxr the resp from slave
			  sif.bvalid <= 1'b0;	//slave is sending invalid data

		  //read addr channel(ar)
		  if(sif.arvalid == 0)		//master is sending invalid data
			  sif.arready <= 0;	//slave is not ready to rxr the data

		  //read data channel(r)
		  if(sif.rready == 0)		//master is not ready to rxr the resp from slave
			  sif.rvalid <= 0;	//slave is sending invalid data


		  //---------> if valid is high
//------------------------>write addr channel
		  if(sif.awvalid == 1) begin
			  sif.awready <= 1;
			  id = sif.awid;
			  wra[sif.awid] = new();
              wra[sif.awid].addr = sif.awaddr;
			  wra[sif.awid].burst= sif.awburst;		  
			  wra[sif.awid].size = sif.awsize;		  
			  wra[sif.awid].prot = sif.awprot;		  
			  wra[sif.awid].lock = sif.awlock;		  
			  wra[sif.awid].len  = sif.awlen;		  
			  wra[sif.awid].cache= sif.awcache;		  
			  wra[sif.awid].id   = sif.awid;
			  wra[9].print();
		  end
//-------------------->write data channel

		  if(sif.wvalid == 1) begin
			sif.wready <= 1;

			//slave need to know the burst type:incr,wrap,fixed

//---------------------------------------------------FIXED transaction---------------------------------------------------------------

			if(wra[sif.wid].burst==0) begin 
			  for(int i=0; i<=wra[sif.wid].len; i++) begin
				@(posedge sif.aclk);
				  case(wra[sif.wid].size) 
					0: begin
						mem[wptr] = sif.wdata[7:0];

						wptr = (wptr + 2**wra[sif.wid].size);
					end
					1: begin
						mem[wptr] = sif.wdata[7:0];
						mem[wptr + 1] = sif.wdata[15:0];

						wptr = wptr + (2**wra[sif.wid].size);
					end
					2: begin
						mem[wptr] = sif.wdata[7:0];
						mem[wptr + 1] = sif.wdata[15:8];
						mem[wptr + 2] = sif.wdata[23:16];
						mem[wptr + 3] = sif.wdata[31:24];


						wptr = wptr + (2**wra[sif.wid].size); // next beat start addr
					end
					3: begin
						for(int i=0; i<(2**wra[sif.wid].size); i++) begin
							mem[wptr+i] = sif.wdata[(i*8)+:8]; //increment operator start at (i*8) upwards to 8
						end

						wptr = wptr + (2**wra[sif.wid].size);
					end
					4: begin
						for(int i=0; i<(2**wra[sif.wid].size); i++) begin
							mem[wptr+i] = sif.wdata[(i*8)+:8]; //increment operator start at (i*8) upwards to 8
						end

						wptr = wptr + (2**wra[sif.wid].size);
					end
					5: begin
						for(int i=0; i<(2**wra[sif.wid].size); i++) begin
							mem[wptr+i] = sif.wdata[(i*8)+:8]; //increment operator start at (i*8) upwards to 8
						end

						wptr = wptr + (2**wra[sif.wid].size);
					end
					6: begin
						for(int i=0; i<(2**wra[sif.wid].size); i++) begin
							mem[wptr+i] = sif.wdata[(i*8)+:8]; //increment operator start at (i*8) upwards to 8
						end

						wptr = wptr + (2**wra[sif.wid].size);
					end
					7: begin
						for(int i=0; i<(2**wra[sif.wid].size); i++) begin
							mem[wptr+i] = sif.wdata[(i*8)+:8]; //increment operator start at (i*8) upwards to 8
						end

						wptr = wptr + (2**wra[sif.wid].size);
					end
				  endcase //awsize
				end //awlen

			end//awburst
//---------------------------------------------------INCR transaction---------------------------------------------------------------

			if(wra[sif.wid].burst==1) begin
			  for(int i=0; i<=wra[sif.wid].len; i++) begin
				@(posedge sif.aclk);
					case(wra[sif.wid].size)
						0: begin	//1byte - active
							cnt = 0;

							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 1 bit 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);
						end
						1: begin	//2bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 2 bits --> 11-2bytes are active; 10-1byte is active 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
						2: begin	//4bytes - active
							case(sif.wstrb)
							  4'b1111: begin
							    mem[wra[sif.wid].addr]       =  sif.wdata[7:0];
							    mem[wra[sif.wid].addr + 1]   =  sif.wdata[15:8];
							    mem[wra[sif.wid].addr + 2]   =  sif.wdata[23:16];
							    mem[wra[sif.wid].addr + 3]   =  sif.wdata[31:24];

							    
							    if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); //it will calc aligned addr
						        end

					                   //next beat start addr
							    wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);
			
							  end
							  4'b1110: begin
							    mem[wra[sif.wid].addr ]      =  sif.wdata[15:8];
							    mem[wra[sif.wid].addr + 1]   =  sif.wdata[23:16];
							    mem[wra[sif.wid].addr + 2]   =  sif.wdata[31:24];
							    
							    //before going to next beat addr calc
							    //now i need calc the current beat aligned addr (unaligned to aligned conv)
							    if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); //it will calc aligned addr
						        end
							    wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);   // prev beat aligned addr + 2**awsize

							  end
							  4'b1100: begin
							    mem[wra[sif.wid].addr]       =  sif.wdata[23:16];
							    mem[wra[sif.wid].addr + 1]   =  sif.wdata[31:24];
							    
							    //before going to next beat addr calc
							    //now i need calc the current beat aligned addr
							    if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); //it will calc aligned addr
						        end
							    wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);   // prev beat aligned addr + 2**awsize

							  end
							  4'b1000: begin
							    mem[wra[sif.wid].addr]   =  sif.wdata[31:24];
							    
							    //before going to next beat addr calc
							    //now i need calc the current beat aligned addr
							    if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); //it will calc aligned addr
						        end
							    wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);   // prev beat aligned addr + 2**awsize

							  end
							endcase

						end
						3: begin	//8bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 8 bits; 8 comb of byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
						4: begin	//16bytes -active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 16 bits; 16 comb of byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
						5: begin	//32bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 32 bits; 32 comb of byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
						6: begin	//64bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 64 bits; 64 comb of byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
						7: begin	//128bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size); i++) begin
								if(sif.wstrb[i] == 1) begin  // wstrb 128 bits; 128 comb of byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
							
							if(wra[sif.wid].addr % (2 ** wra[sif.wid].size) != 0) begin
							      wra[sif.wid].addr = (wra[sif.wid].addr - (wra[sif.wid].addr % 2**wra[sif.wid].size)); 
							      //it will calc aligned addr
						    end

					                //next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

						end
					endcase	//awsize


				end//awlen
			end//awburst

//---------------------------------------------------WRAP transaction---------------------------------------------------------------

			else if(wra[sif.awid].burst==2)begin    // wrap burst
			  if(wra[sif.wid].addr % (2**(wra[sif.wid].size)) == 0)  begin // aligned check
			    beats = wra[sif.wid].len + 1; //no of beats
			    if(beats == 2 || beats == 4 || beats == 8 || beats == 16) begin  // beats checks
				k = wra[sif.wid].addr / ((2**wra[sif.wid].size)*beats);
				wrap_boundary_addr = k * ((2**wra[sif.wid].size)*(beats));
				upper_boundary_addr = wrap_boundary_addr + ((2**wra[sif.wid].size)*beats);

				for(int i=0; i<=wra[sif.wid].len; i++) begin
				   @(posedge sif.aclk);
					case(wra[sif.wid].size)
						0: begin	//1byte - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 1 bit: 1-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end
							
						end
						1: begin	//2bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 2 bit: 2-byte selection 
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
						2: begin	//4bytes - active
							cnt = 0;
							case(sif.wstrb)
							  4'b1111: begin
							    mem[wra[sif.wid].addr]       =  sif.wdata[7:0];
							    mem[wra[sif.wid].addr + 1]   =  sif.wdata[15:8];
							    mem[wra[sif.wid].addr + 2]   =  sif.wdata[23:16];
							    mem[wra[sif.wid].addr + 3]   =  sif.wdata[31:24];
							    
							    
					                   //next beat start addr
							    wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							    if(wra[sif.wid].addr == upper_boundary_addr) begin
								wra[sif.wid].addr = wrap_boundary_addr;
							    end
			
							  end
                 			endcase

						end
						3: begin	//8bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 8 bit: 8-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
						4: begin	//16bytes -active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 16 bit: 16-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
						5: begin	//32bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 32 bit: 32-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
						6: begin	//64bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 64 bit: 64-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
						7: begin	//128bytes - active
							cnt = 0;
							for(int i=0; i<(2**wra[sif.wid].size);i++) begin
								if(sif.wstrb[i]== 1) begin // wstrb 128 bit: 128-byte selection
									mem[wra[sif.wid].addr + cnt] = sif.wdata[(i*8)+:8];
									cnt = cnt + 1;
								end
							end
					                 
							//next beat start addr
							wra[sif.wid].addr = wra[sif.wid].addr + 2**(wra[sif.wid].size);

							if(wra[sif.wid].addr == upper_boundary_addr) begin
							  wra[sif.wid].addr = wrap_boundary_addr;
							end

						end
					endcase	//awsize


				end//awlen
			       end // beats
		       	       else begin
				       resp = EXOKAY; //error response
			       end	       
			  end //aligned addr or not 
			  else begin
				resp = EXOKAY; //error response
			  end
			end//awburst



		  end//wvalid

//-------------------->write response channel
		  if(sif.wlast == 1) begin
			id = sif.wid;
			@(posedge sif.aclk);
			if(sif.bready == 1) begin
			  sif.bvalid <= 1'b1; 
			  sif.bresp <= OKAY; 
			  sif.bid <= id;
			@(posedge sif.aclk);
			 resp = OKAY; //ok response
			end//bready
		   end//wlast

	
//-------------------->read addr channel
		  if(sif.arvalid == 1) begin
			  sif.arready <= 1;
			  rda[sif.arid] = new();
              rda[sif.arid].addr = sif.araddr;
			  rda[sif.arid].burst= sif.arburst;		  
			  rda[sif.arid].size = sif.arsize;		  
			  rda[sif.arid].prot = sif.arprot;		  
			  rda[sif.arid].lock = sif.arlock;		  
			  rda[sif.arid].len  = sif.arlen;		  
			  rda[sif.arid].cache= sif.arcache;		  
			  rda[sif.arid].id   = sif.arid;		  
		  end//arvalid

//-------------------->read data channel
		  if(sif.rready==1) begin
			if(rda.size()>0) begin
				rda.first(temp_id);
//-----------------------------------------------------------fixed read--------------------------------------------------------------
				if(rda[temp_id].burst == 0) begin
					sif.rvalid <= 1'b1;
					for(int i=0; i<=rda[temp_id].len; i++) begin
						case(rda[temp_id].size)
							0: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							1: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							2: begin
								sif.rdata = {mem[rptr + 3],
									      mem[rptr + 2],
									      mem[rptr + 1],
									      mem[rptr]};
							        
							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							3: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							4: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							5: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							6: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
							7: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rptr+i];
								end

								sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rptr = rptr + (2**rda[temp_id].size);
							end
						endcase //awsize
						@(posedge sif.aclk);
						sif.rlast <= 1'b0;
					end//for

				end //fixed
//------------------------------------------------------------increment read----------------------------------------------------------
				if(rda[temp_id].burst==1) begin
					sif.rvalid <= 1'b1;
					for(int i=0; i<=rda[temp_id].len; i++) begin
						case(rda[temp_id].size)
							0: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

							end
							1: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							2: begin
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								sif.rdata = {mem[rda[temp_id].addr+3],
									      mem[rda[temp_id].addr+2],
									      mem[rda[temp_id].addr+1],
									      mem[rda[temp_id].addr]};
							        
							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							3: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							4: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							5: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							6: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
							7: begin
								//unaligned to aligned convertion
								if(rda[temp_id].addr % (2**rda[temp_id].size) !=0) begin
								  rda[temp_id].addr = rda[temp_id].addr - (rda[temp_id].addr % (2**rda[temp_id].size));
							  	end

								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							        sif.rid <= temp_id;
								sif.rresp <= OKAY;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end
								
								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
							end
						endcase
						@(posedge sif.aclk);
						sif.rlast <= 1'b0;
					end//for
				end//incr
//--------------------------------------------------------------wrap  read-------------------------------------------------------------------
				if(rda[temp_id].burst == 2) begin
				  sif.rvalid <= 1'b1;
				  if(rda[temp_id].addr % (2**rda[temp_id].size) == 0) begin
				    beats = rda[temp_id].len + 1; //no of beats
			      	    if(beats == 2 || beats == 4 || beats == 8 || beats == 16) begin
				      k = rda[temp_id].addr / ((2**rda[temp_id].size)*beats);
				      wrap_boundary_addr = k * ((2**rda[temp_id].size)*beats);
				      upper_boundary_addr = wrap_boundary_addr + ((2**rda[temp_id].size)*beats);

					for(int i=0; i<=rda[temp_id].len; i++) begin
						case(rda[temp_id].size)
							0: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end

							end
							1: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							2: begin
								
								sif.rdata = {mem[rda[temp_id].addr+3],
									      mem[rda[temp_id].addr+2],
									      mem[rda[temp_id].addr+1],
									      mem[rda[temp_id].addr]};
							        
								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							3: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

							
								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							4: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							5: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <=OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							6: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
							7: begin
								for(int i=0; i<(2**rda[temp_id].size); i++) begin
									sif.rdata[(i*8)+:8] = mem[rda[temp_id].addr + i];
								end

								sif.rresp <= OKAY;
							        sif.rid <= temp_id;
								if(i == rda[temp_id].len) begin
									sif.rlast <= 1'b1;
								end

								//next beat start addr
								rda[temp_id].addr = rda[temp_id].addr + (2**rda[temp_id].size);

								//addr touches U.B.A needs to replace it with W.B.A
								if(rda[temp_id].addr == upper_boundary_addr) begin
									rda[temp_id].addr = wrap_boundary_addr;
								end
							end
						endcase
						@(posedge sif.aclk);
						sif.rlast <= 1'b0;
					end//for

				    end//beats check
				    else begin
					sif.rresp <= EXOKAY;
				    end
	
				  end//aligned check
				  else begin
			            sif.rresp <= EXOKAY;
				  end

				end //wrapped

				rda.delete(temp_id);
			end//rda.size>0

		  end//rready


		end//else
	  end//forever
	endtask


endclass : axi_slave_driver
