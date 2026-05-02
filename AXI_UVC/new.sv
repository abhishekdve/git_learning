// axi_driver_fifo.sv
// UVM AXI Master Driver implementing channel-parallelism using FIFOs
// Assumptions:
// - axi_tx extends uvm_sequence_item and implements clone() properly
// - virtual interface provides 'clk' and a clocking block 'axi_driver_cb'
// - uvm_tlm_fifo#(axi_tx) is available. If not, switch to mailbox or uvm_queue.

class axi_drv extends uvm_driver#(axi_tx);
  `uvm_component_utils(axi_drv)

  // virtual interface handle (provided via config db)
  virtual axi_intf.axi_driver_mp vif;

  // FIFOs for channel-level decoupling
  uvm_tlm_fifo#(axi_tx) aw_fifo;
  uvm_tlm_fifo#(axi_tx) w_fifo;
  uvm_tlm_fifo#(axi_tx) ar_fifo;

  // Map outstanding write transactions by ID to the transaction object (for B matching)
  // simple associative array keyed by int
  typedef axi_tx axi_tx_t;
  axi_tx_t outstanding_writes[string]; // key: string(id) to be safe

  // Constructor
  function new(string name = "axi_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // create bounded FIFOs to model channel saturation/backpressure
    // sizes are examples; adjust to desired outstanding depth
    aw_fifo = new("aw_fifo", 16);
    w_fifo  = new("w_fifo", 32);
    ar_fifo = new("ar_fifo", 16);

    if (!uvm_config_db#(virtual axi_intf.axi_driver_mp)::get(this, "", "axi_intf", vif))
      `uvm_fatal("DRIVER", "axi_intf not received in driver build_phase")
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);

    // spawn channel threads — they run forever (or until simulation end)
    fork
      seq_receiver_thread(); // receives seq items and sorts them into FIFOs
      aw_thread();
      w_thread();
      b_thread();
      ar_thread();
      r_thread();
    join_none

    // driver stays alive until end_of_sim
    wait (0);
  endtask

  //-------------------------------------------------------------------
  // Sequencer receiver: get items and enqueue into appropriate FIFOs
  //-------------------------------------------------------------------
  task seq_receiver_thread();
    axi_tx tx;
    axi_tx tx_aw_clone, tx_w_clone, tx_ar_clone;

    forever begin
      seq_item_port.get_next_item(tx); // blocking until seq gives an item

      // clone item(s) before putting into FIFOs to avoid handle-sharing races
      if (tx.wr_rd) begin
        // write transaction: needs AW and W channels
        tx_aw_clone = tx.clone();
        tx_w_clone  = tx.clone();

        // Put into AW and W FIFOs (blocking if FIFO full)
        aw_fifo.put(tx_aw_clone);
        w_fifo.put(tx_w_clone);

        // optionally keep a handle for matching B responses
        // store original tx in outstanding map keyed by id
        string id_key = $sformatf("%0d", tx.id);
        outstanding_writes[id_key] = tx; // original sequence item (not clone)

        // inform sequencer we are done with this item. We freed the seq item
        seq_item_port.item_done();
      end
      else begin
        // read transaction: needs AR channel. R responses will be collected and pushed into tx.respQ
        tx_ar_clone = tx.clone();
        ar_fifo.put(tx_ar_clone);

        // do we wait for read completion before item_done? Typical patterns either
        // - return item_done immediately (allow seq to continue) and deliver responses asynchronously
        // - or block until R collected and then item_done
        // Here we choose to return immediately to allow pipelining; adjust if you want handshake semantics
        seq_item_port.item_done();
      end

    end
  endtask

  //-------------------------------------------------------------------
  // AW thread: drives write address channel
  //-------------------------------------------------------------------
  task aw_thread();
    axi_tx tx_local;

    forever begin
      // get blocks until item available
      aw_fifo.get(tx_local);

      // drive AW on clocked edges using clocking block or explicit clk
      // assume clocking block named axi_driver_cb exists
      @(posedge vif.clk);
      vif.axi_driver_cb.awaddr  = tx_local.addr;
      vif.axi_driver_cb.awid    = tx_local.id;
      vif.axi_driver_cb.awlen   = tx_local.len;
      vif.axi_driver_cb.awsize  = tx_local.size;
      vif.axi_driver_cb.awburst = tx_local.burst;
      vif.axi_driver_cb.awlock  = tx_local.lock;
      vif.axi_driver_cb.awprot  = tx_local.prot;
      vif.axi_driver_cb.awcache = tx_local.cache;
      vif.axi_driver_cb.awvalid = 1'b1;

      // keep awvalid until accepted
      forever begin
        @(posedge vif.clk);
        if (vif.axi_driver_cb.awready) begin
          vif.axi_driver_cb.awvalid = 1'b0; // deassert next cycle
          @(posedge vif.clk);
          // clear signals
          vif.axi_driver_cb.awaddr  = '0;
          vif.axi_driver_cb.awid    = '0;
          vif.axi_driver_cb.awlen   = '0;
          vif.axi_driver_cb.awsize  = '0;
          vif.axi_driver_cb.awburst = '0;
          vif.axi_driver_cb.awlock  = '0;
          vif.axi_driver_cb.awprot  = '0;
          vif.axi_driver_cb.awcache = '0;
          break;
        end
      end
    end
  endtask

  //-------------------------------------------------------------------
  // W thread: drives write data channel (burst beats)
  //-------------------------------------------------------------------
  task w_thread();
    axi_tx tx_local;
    int beats;

    forever begin
      w_fifo.get(tx_local);

      // assume tx_local.dataQ and strbQ are arrays/queues accessible by index
      beats = tx_local.len + 1; // AWLEN semantics assumed

      for (int i = 0; i < beats; i++) begin
        @(posedge vif.clk);
        vif.axi_driver_cb.wid   = tx_local.id;
        vif.axi_driver_cb.wdata = tx_local.dataQ[i];
        vif.axi_driver_cb.wstrb = tx_local.strbQ[i];
        vif.axi_driver_cb.wlast = (i == beats-1);
        vif.axi_driver_cb.wvalid = 1'b1;

        // hold until accepted
        forever begin
          @(posedge vif.clk);
          if (vif.axi_driver_cb.wready) begin
            vif.axi_driver_cb.wvalid = 1'b0;
            @(posedge vif.clk);
            vif.axi_driver_cb.wid   = '0;
            vif.axi_driver_cb.wdata = '0;
            vif.axi_driver_cb.wstrb = '0;
            vif.axi_driver_cb.wlast = 1'b0;
            break;
          end
        end
      end
    end
  endtask

  //-------------------------------------------------------------------
  // B thread: collects write responses and matches to outstanding tx
  //-------------------------------------------------------------------
  task b_thread();
    axi_tx matched_tx;
    string id_key;

    forever begin
      // wait for bvalid
      @(posedge vif.clk);
      if (vif.axi_driver_cb.bvalid) begin
        // sample bresp and bid
        int bid = vif.axi_driver_cb.bid;
        int bresp = vif.axi_driver_cb.bresp;

        // assert bready for one cycle
        vif.axi_driver_cb.bready = 1'b1;
        @(posedge vif.clk);
        vif.axi_driver_cb.bready = 1'b0;

        id_key = $sformatf("%0d", bid);
        if (outstanding_writes.exists(id_key)) begin
          matched_tx = outstanding_writes[id_key];
          // push response into transaction (user-defined field)
          matched_tx.bresp = bresp;

          // notify sequence or scoreboard as required (example uvm_info)
          `uvm_info(get_type_name(), $sformatf("B response for id=%0d resp=%0d", bid, bresp), UVM_MEDIUM)

          // remove from outstanding writes; if multiple outstanding with same id exist, app must manage list
          outstanding_writes.delete(id_key);
        end
        else begin
          `uvm_warning(get_type_name(), $sformatf("Received B for unknown id %0d", bid))
        end
      end
    end
  endtask

  //-------------------------------------------------------------------
  // AR thread: drives read address channel
  //-------------------------------------------------------------------
  task ar_thread();
    axi_tx tx_local;

    forever begin
      ar_fifo.get(tx_local);

      @(posedge vif.clk);
      vif.axi_driver_cb.araddr  = tx_local.addr;
      vif.axi_driver_cb.arid    = tx_local.id;
      vif.axi_driver_cb.arlen   = tx_local.len;
      vif.axi_driver_cb.arsize  = tx_local.size;
      vif.axi_driver_cb.arburst = tx_local.burst;
      vif.axi_driver_cb.arlock  = tx_local.lock;
      vif.axi_driver_cb.arprot  = tx_local.prot;
      vif.axi_driver_cb.arcache = tx_local.cache;
      vif.axi_driver_cb.arvalid = 1'b1;

      forever begin
        @(posedge vif.clk);
        if (vif.axi_driver_cb.arready) begin
          vif.axi_driver_cb.arvalid = 1'b0;
          @(posedge vif.clk);
          // clear fields
          vif.axi_driver_cb.araddr  = '0;
          vif.axi_driver_cb.arid    = '0;
          vif.axi_driver_cb.arlen   = '0;
          vif.axi_driver_cb.arsize  = '0;
          vif.axi_driver_cb.arburst = '0;
          vif.axi_driver_cb.arlock  = '0;
          vif.axi_driver_cb.arprot  = '0;
          vif.axi_driver_cb.arcache = '0;
          break;
        end
      end
    end
  endtask

  //-------------------------------------------------------------------
  // R thread: collects read data beats and pushes into tx.respQ
  //-------------------------------------------------------------------
  task r_thread();
    axi_tx tx_local;
    int rid;
    int beats_expected;

    forever begin
      @(posedge vif.clk);
      if (vif.axi_driver_cb.rvalid) begin
        // capture
        rid = vif.axi_driver_cb.rid;
        // find the matching transaction — depends on how you stored read txs
        // For simplicity, assume seq stored read transactions somewhere accessible by id
        // Here we'll assume the read seq is notified elsewhere; but we'll show pushing into a generic scoreboard

        // one-cycle rready pulse
        vif.axi_driver_cb.rready = 1'b1;
        // user can capture data
        `uvm_info(get_type_name(), $sformatf("R id=%0d data=0x%0h resp=%0d last=%0d", rid, vif.axi_driver_cb.rdata, vif.axi_driver_cb.rresp, vif.axi_driver_cb.rlast), UVM_LOW)
        @(posedge vif.clk);
        vif.axi_driver_cb.rready = 1'b0;
      end
    end
  endtask

endclass

