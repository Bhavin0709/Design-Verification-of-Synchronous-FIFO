class transaction;
  rand bit oper;
  bit wr, rd, empty, full;
  bit [7:0] din;
  bit [7:0] dout;
  
  constraint oper_ctrl{
    oper dist{1:/50, 0:/50};
  }
  
endclass

/////////////////  generator

class generator;
  
  transaction tr;
  mailbox #(transaction) mbx;
  
  event next, done;
  
  int count = 0, i = 0;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    repeat(count)
      begin
        assert(tr.randomize) else $error("Randomization Failed");
        mbx.put(tr);
        i++;
        $display("[GEN] oper : %d count : %d", tr.oper, i);
        @(next);
      end
    
    -> done;
    
  endtask
  
endclass

/////////////////  driver

class driver;
  transaction tr;
  mailbox #(transaction) mbx;
  virtual fifo fif;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  
  task reset();
    fif.rst <= 1;
    fif.wr <= 0;
    fif.rd <= 0;
    fif.din <= 0;
    repeat(3) @(posedge fif.clk);
    fif.rst <= 0;
    $display("[DRV] reset Done..............");
  endtask
  
  
  task write();
    @(posedge fif.clk);
    fif.rst <= 0;
    fif.wr <= 1;
    fif.rd <= 0;
    fif.din = $urandom_range(1,255);
    @(posedge fif.clk);
    fif.wr <= 0;
    $display("[DRV] Write done din : %d", fif.din);
    @(posedge fif.clk);
  endtask
  
  
  task read();
    @(posedge fif.clk);
    fif.rst <= 0;
    fif.wr <= 0;
    fif.rd <= 1;
    @(posedge fif.clk);
    fif.rd <= 0;
    @(posedge fif.clk);
  endtask
  
  
  task run();
    forever
      begin
        mbx.get(tr);
        if(tr.oper)
      		write();
    	else 
      		read();
      end
    
  endtask
  
endclass

/////////////////  monitor

class monitor;
  transaction tr;
  mailbox #(transaction)mbx;
  virtual fifo fif;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    tr = new();
    forever 
      begin
        repeat(2) @(posedge fif.clk);
        tr.wr = fif.wr;
        tr.rd  = fif.rd;
        tr.din = fif.din;
        tr.full = fif.full;
        tr.empty = fif.empty;
        @(posedge fif.clk);
        tr.dout = fif.dout;
        
        mbx.put(tr);
        $display("[MON] data sent to scoreboard");
        
      end
    
  endtask
  
endclass



class scoreboard;
  transaction tr;
  mailbox #(transaction) mbx;
  event next;
  
  bit [7:0] din[$];
  bit [7:0] temp;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  
  task run();
    forever 
      begin
        mbx.get(tr);
        
        if(tr.wr)
          if(!tr.full)
            din.push_front(tr.din);
          else
            $display("FIFO is full !!");
        
        if(tr.rd)
          if(!tr.empty)
            begin
              temp = din.pop_back();
              
              if(temp == tr.dout)
                $display("DATA MATCHED: dout : %d", tr.dout);
              else
                $display("DATA us not matched");
            end
          else
            $display("FIFO is empty");
        $display("------------------------------");
        -> next;
        
      end
  endtask

endclass 



class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox #(transaction) mbxgd;
  mailbox #(transaction) mbxms;
  
  virtual fifo fif;
  
  event nextgs;
  
  
  function new(virtual fifo fif);
    mbxgd = new();
    mbxms = new();
    gen = new(mbxgd);
    drv = new(mbxgd);
    mon = new(mbxms);
    sco = new(mbxms);
    
    this.fif = fif;
    drv.fif = this.fif;
    mon.fif = this.fif;
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork 
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $display("Testing done");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass




module tb;
  fifo fif();
  
  FIFO F1(fif.din, fif.clk, fif.rst, fif.wr, fif.rd, fif.dout, fif.empty, fif.full);
  
  environment env;
  
  initial 
    begin
      fif.clk = 0;
    end
  
  always #5 fif.clk = ~fif.clk;
  
  initial 
    begin
      env = new(fif);
      env.gen.count = 20;
      env.run();
    end
  
  initial 
    begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
  
endmodule
    
