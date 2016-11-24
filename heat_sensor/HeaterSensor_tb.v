`timescale 1ns/1ns

module HeatSensor_tb();

reg         clk,rst,read,write;
reg  [31:0] writedata;
wire [31:0] readdata;

initial       clk       = 1'b0;
always  #5    clk       = ~clk;

initial       rst       = 1'b0;
initial #10   rst       = 1'b1;
initial #20   rst       = 1'b0;

initial 		  write     = 1'b0;
initial       writedata = 32'b0;

initial #25   write     = 1'b1;
initial #25   writedata = 32'b0;
initial #35   write     = 1'b0;
initial #35   writedata = 32'b0;

initial #1025 write     = 1'b1;
initial #1025 writedata = 32'b1;
initial #1035 write     = 1'b0;
initial #1035 writedata = 32'b0;

initial #5000 $stop;

HeatSensor hs0(
		.avs_s0_readdata(readdata),          //    s0.readdata
		.avs_s0_write(write),     				 //      .write
		.avs_s0_writedata(writedata), 		 //      .writedata
		.avs_s0_read(read),      				 //      .read
		.clk	(clk),              				 // clock.clk
		.reset(rst)            					 // reset.reset
	);
	
always@(write)
 if(writedata==32'b1)
  $display(" Enabling Heat Generator ");
 else
  $display(" Disabling Heat Generator "); 
  
  
always@(readdata)
 $display(" $ %d " , readdata );  


endmodule
