`timescale 1ns/1ns

module Cache_tb();

  reg     clk,rst;
  
  initial     clk = 1'b1;
  always  #10 clk = ~clk;
  
  initial     rst = 1'b1;
  initial #20 rst = 1'b0;
  
  reg  s0_read  , s1_read  , s2_read;
  reg  s0_write , s1_write , s2_write;
  wire [31:0]  s0_readdata , s1_readdata , s2_readdata , m0_writedata ;
  reg  [31:0]  s0_writedata , s1_writedata , s2_writedata , m0_readdata;    
  wire s0_wait , s1_wait , s2_wait;
  reg  m0_wait;
  wire m0_read , m0_write;
  
  reg  [27:0] s0_address , s1_address , s2_address;
  wire [27:0] m0_address;
  
  Cache c0( 
         .clk(clk),
         .reset(rst),
         
         .avs_s0_address(s0_address),     //    s0.address         
		     .avs_s0_read(s0_read),        
  		     .avs_s0_readdata(s0_readdata),
		     .avs_s0_write(s0_write),       
  		     .avs_s0_writedata(s0_writedata),
  		     .avs_s0_waitrequest(s0_wait),
  		     
  		     .avs_s1_address(s1_address),
  		     .avs_s1_read(s1_read),        
  		     .avs_s1_readdata(s1_readdata),
		     .avs_s1_write(s1_write),       
  		     .avs_s1_writedata(s1_writedata),
  		     .avs_s1_waitrequest(s1_wait),
  		     
  		     .avs_s2_address(s2_address),
  		     .avs_s2_read(s2_read),        
  		     .avs_s2_readdata(s2_readdata),
		     .avs_s2_write(s2_write),       
  		     .avs_s2_writedata(s2_writedata),
  		     .avs_s2_waitrequest(s2_wait),
  		     
  		     .avm_m0_address(m0_address),     //    m0.address
		     .avm_m0_read(m0_read),        //      .read
		     .avm_m0_waitrequest(m0_wait), //      .waitrequest
		     .avm_m0_readdata(m0_readdata),    //      .readdata
  		     .avm_m0_write(m0_write),       //      .write
  		     .avm_m0_writedata(m0_writedata)  //      .writedata
  		     
 		   );

  initial m0_wait = 1'b0;
 		   
 	initial #30 s0_address <= 28'h0001000;
 	initial #30 s0_read    <= 1'b1;	
 	
 	always@(s0_wait)
 	  if(s0_wait==1'b0)
 	    begin
   	    $display( " s0 : readdata %x " , s0_readdata );   
   	    s0_read <= 1'b0;  
 	    end
 	    
 	      
  
  /*
  reg  [31:0] a ;
  reg  [ 4:0] b ;
  
  wire [ 4:0] c;
  wire        d;

 
  GetNextNeighborWrapper m0 ( .clk(clk) , .rst(rst) , .next(c) , .end_of_list(d) );
       
  initial a <= 32'b00100000001000000010000000100000;
  
  
  always@(c or d)
    begin
     $display(" %d - %b " , c , d );    
    end 
 
  */              
  initial #1000 $stop;
                
endmodule  