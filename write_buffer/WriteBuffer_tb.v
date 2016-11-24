`timescale 1ns/1ns

module WriteBuffer_tb();

reg         clk , rst;             

reg  [31:0] s_addr   , s_wrdata ; 
reg  [ 3:0] s_byteen;
reg         s_rd , s_wr , s_cs;

wire [31:0] s_rddata ;
wire        s_rddatavalid , s_waitrq;

wire [31:0] m_addr   , m_wrdata ; 
wire [ 3:0] m_byteen;
wire        m_rd , m_wr , m_cs;

reg  [31:0] m_rddata ;
reg         m_rddatavalid , m_waitrq;

  
  WriteBuffer wb0(
                    .clk                 (clk          ),
                    .reset               (rst          ),
                    
                    /* SLAVE port signals */
                    .avs_s0_address      (s_addr       ),
						        .avs_s0_readdata     (s_rddata     ),						       
                    .avs_s0_writedata    (s_wrdata     ),
                    .avs_s0_byteenable   (s_byteen     ),
						        .avs_s0_read         (s_rd         ),
                    .avs_s0_write        (s_wr         ),
                    .avs_s0_readdatavalid(s_rddatavalid), 
						        .avs_s0_waitrequest  (s_waitrq     ),
                    .avs_s0_chipselect   (s_cs         ),
						
              						/* MASTER  port signals */
                    .avm_m0_address      (m_addr       ),
                    .avm_m0_readdata     (m_rddata     ),
                    .avm_m0_writedata    (m_wrdata     ),
                    .avm_m0_byteenable   (m_byteen     ),
                    .avm_m0_read         (m_rd         ),
                    .avm_m0_write        (m_wr         ),
                    .avm_m0_readdatavalid(m_rddatavalid),
                    .avm_m0_waitrequest  (m_waitrq     ),
                    .avm_m0_chipselect   (m_cs         )
                 );

initial     clk = 1'b0;
always   #5 clk = ~clk;

initial     rst = 1'b1;
initial #20 rst = 1'b0;
initial #30 rst = 1'b1;

initial     s_cs      = 1'b0; 
initial     m_waitrq  = 1'b1;
initial     m_rddata  = 32'h50505050;

/* test read miss in writer buffer => buffer shoudl forward this request to MASTER port */

initial #50 s_cs     = 1'b1;              
initial #45 s_rd     = 1'b1;
initial #45 s_byteen = 4'b1111;
initial #45 s_addr   = 32'h10001000;
                      
initial #60 m_waitrq = 1'b0;
          
initial #70 s_cs     = 1'b0;
initial #70 s_rd     = 1'b0;

/* test buffer write policy */

initial #90  m_waitrq = 1'b1;

initial #100 s_wr     = 1'b1;
initial #100 s_wrdata = 32'hA0A0A0A0;
initial #100 s_addr   = 32'h00002000;
initial #100 s_cs     = 1'b1; /* write 1st word */

initial #110 s_wrdata = 32'h21212121;
initial #110 s_addr   = 32'h00003000;
initial #110 s_cs     = 1'b1; /* write 1st word */

initial #120 s_cs     = 1'b0;

initial #130 m_waitrq = 1'b0;
            
always@(s_cs or s_waitrq or m_cs or m_waitrq )
 begin
  $display( " Slave  : Addr %h , rd_dat %h , wr_data %h , read %b , write %b , waitreq %b , cs %b \n" , s_addr , s_rddata , s_wrdata , s_rd , s_wr , s_waitrq , s_cs );
  $display( " Master : Addr %h , rd_dat %h , wr_data %h , read %b , write %b , waitreq %b , cs %b \n" , m_addr , m_rddata , m_wrdata , m_rd , m_wr , m_waitrq , m_cs );
  $display( "-------------------------------------------------------------------------------------\n" );
 end
  
initial #200 $stop;           

endmodule
 