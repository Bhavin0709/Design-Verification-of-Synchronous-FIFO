module FIFO(
  input [7:0] din,
  input clk, rst, wr, rd,
  output reg [7:0] dout,
  output empty, full);
  
  reg [7:0] mem [0:15];
  reg [3:0] wcount = 0, rcount = 0;
  reg [4:0] count = 0;
  
  
  always@(posedge clk)
    begin
      if(rst)
        begin
          wcount <= 0;
          rcount <= 0;
          count <= 0;
        end 
      
      else if(wr && !full)
        begin
          mem[wcount] <= din;
          wcount <= wcount + 1;
          count <= count + 1;
        end 
      
      else if(rd && !empty)
        begin
          dout <= mem[rcount];
          rcount <= rcount + 1;          
          count <= count - 1;
        end
      
    end 
  
  assign full = (count == 16) ? 1'b1 : 1'b0;
  assign empty = (count == 0) ? 1'b1 : 1'b0;
  
endmodule 


interface fifo;
  
  logic [7:0] din;
  logic clk, rst, wr, rd;
  logic [7:0] dout;
  logic empty, full;
  
endinterface
