/*
 *	WriteBuffer.v
 *	
 *	Author      : Kamyar Mirzazad ( kammirzazad@ee.sharif.edu )
 *	Subject	    : Avalon interface compatible Merging Write Buffer [ without support for pipelined transactions ]
 *	Created  On : Mar 31 , 2014
 *  Modified On : Apr  3 , 2014
 *
 *	To Do		:
 *  			  - Create testbench and check module's timing
 *				  - Place module in NIOS2 system and check overall functionality
 */

module WriteBuffer (
						input  wire 	   clk,
						input  wire		   reset,

						/* SLAVE   port signals */
						input  wire [31:0] avs_s0_address,
						output wire [31:0] avs_s0_readdata,		 /* missing?				   */ 
						input  wire [31:0] avs_s0_writedata,
						input  wire [ 3:0] avs_s0_byteenable,
						input  wire        avs_s0_read,
						input  wire		   avs_s0_write,
						output wire        avs_s0_readdatavalid, /* for pipelined transactions */
						output wire        avs_s0_waitrequest,   /* driven by ASSIGN statement */
						input  wire		   avs_s0_chipselect,
						
						/* MASTER  port signals */
						output wire [31:0] avm_m0_address,
						input  wire [31:0] avm_m0_readdata,
						output wire [31:0] avm_m0_writedata,
						output wire [ 3:0] avm_m0_byteenable,
						output wire        avm_m0_read,
						output wire		   avm_m0_write,
						input  wire        avm_m0_readdatavalid,
						input  wire        avm_m0_waitrequest,
						output wire        avm_m0_chipselect
				    );

	integer   i;
	parameter N = 16; /* Maximum number of entries in buffer */
	parameter M =  4; /* LOG2(N) */
	
	reg			 slave_waitrequest, 
				 master_read,
				 master_write,
				 master_chipselect,
				 ongoingrequest;
	
	reg	 [ 31:0] slave_readdata;	
	reg  [ 31:0] master_address;
	reg	 [ 31:0] master_writedata;
	reg	 [  3:0] master_byteenable;
	
	/* SLAVE  assignments */
	assign avs_s0_readdata	  = slave_readdata;
	assign avs_s0_waitrequest = slave_waitrequest;
	
	/* MASTER assignments */
	assign avm_m0_read		  = master_read;
	assign avm_m0_write		  = master_write;
	assign avm_m0_address     = master_address;
	assign avm_m0_writedata   = master_writedata;
	assign avm_m0_byteenable  = master_byteenable;
	assign avm_m0_chipselect  = master_chipselect;

	/* FIFO */
	reg  [ 31:0] data [N-1:0]; 		/*       data */
	reg  [ 31:0] addr [N-1:0]; 		/*    address */
	reg	 [  3:0] val  [N-1:0]; 		/* valid bits */
	
	wire [M-1:0]   wrt_ptr;
	reg  [M-1:0]  fifo_ptr;		
    reg  [M-1:0]  find_ptr_wr, find_ptr_rd;
	reg  [N-1:0]   isFound_wr,  isFound_rd;
	
	wire		 rd_ready, wr_ready, mem_ready;
	
	/* Search FIFO for requested address (WRITE) */
	always@(*)
		for(i=0;i<N;i=i+1)
		  begin
			 isFound_wr[i] =   (|val[i]) & (avs_s0_address == addr[i]) ;
			find_ptr_wr    = ( (|val[i]) & (avs_s0_address == addr[i]) )? i : {M{1'bz}}; 			 
		  end
		  
	/* Search FIFO for requested address (READ)  */	  
	always@(*)
		for(i=0;i<N;i=i+1)
		  begin
			 isFound_rd[i] =   (&val[i]) & (avs_s0_address == addr[i]) ;
			find_ptr_rd    = ( (&val[i]) & (avs_s0_address == addr[i]) )? i : {M{1'bz}}; 			 
		  end
		  
	assign wrt_ptr     = (|isFound_wr[N-1:0]) ?  find_ptr_wr : fifo_ptr; 						/* Determine destination for WRITE 									*/
	
	assign wr_ready    = (|isFound_wr[N-1:0]) || 				   								/* WRITE is ready if requested address is found in FIFO				*/	
						 (fifo_ptr!={M{1'b0}});  				   								/*  			  or FIFO is not full 								*/
					  
	assign rd_ready    = (|isFound_rd[N-1:0]) ||                  	 							/* READ  is ready if requested address is found in FIFO 			*/
						 (mem_ready);   						   								/*  			  or main memory returned that requested address 	*/

	assign mem_ready   = master_read && (!avm_m0_waitrequest);
	
	always@(posedge clk or negedge clk or negedge reset)
		begin
			if ( clk == 1 ) /* posedge : initiate MASTER requests */
				begin
					if ( ongoingrequest == 0 )
						begin						   
						
							if ( slave_waitrequest && avs_s0_read )
								begin
									/* there is an ongoing request in SLAVE port , if requests is READ make new READ requests */
									master_read		  <= 1'b1;
									master_address    <= avs_s0_address;
									master_chipselect <= 1'b1;
									master_byteenable <= 4'b1111;
									ongoingrequest 	  <= 1'b1;
								end
							else if ( fifo_ptr != N-1 )											/* Initiate new WRITE transaction ( if FIFO is not empty ) */
								begin									
									master_write      <= 1'b1;
									master_writedata  <= data[N-1];
									master_address    <= addr[N-1];
									master_chipselect <= 1'b1;
									master_byteenable <=  val[N-1];
									ongoingrequest 	  <= 1'b1;
									
									/* Since all data & address lines are buffered , now that we made request we can remove last item from FIFO */
											 
									for (i=0; i<N-1; i=i+1)										/* Dequeue from FIFO */
										begin
											data[i+1] <= data[i];
											addr[i+1] <= addr[i];
											 val[i+1] <=  val[i];
										end
							
									fifo_ptr <= fifo_ptr + 1;									/* Increment pointer */	
								end
						end
				end
			else			/* negedge : check requests made to SLAVE port */
				begin
					if ( avs_s0_chipselect && (!slave_waitrequest) )							/* Process new transaction , nothing to do if SLAVE has already asserted waitrequest */
						begin
						
							if ( avs_s0_write )						
								begin
									slave_waitrequest <= !wr_ready;					/* Deassert waitrequest if requested data is already in FIFO */
						
									if ( wr_ready )												/* Wait if FIFO is full			 */
										begin
										
										/* Enqueue to FIFO : If data found in FIFO write in that location o.w. write in fifo_ptr */ 
										
										addr[wrt_ptr] <= avs_s0_address;
										 val[wrt_ptr] <= val[wrt_ptr] | avs_s0_byteenable;		/* Update valid flags			 */		
							
										fifo_ptr <= fifo_ptr - !(|isFound_wr[N-1:0]);			/* Decrement pointer			 */
							
										if ( avs_s0_byteenable[0] )
											data[wrt_ptr][ 7: 0] <= avs_s0_writedata[ 7: 0]; 	/* Write 1st byte				 */
							 
										if ( avs_s0_byteenable[1] )
											data[wrt_ptr][15: 8] <= avs_s0_writedata[15: 8]; 	/* Write 2nd byte				 */
							
										if ( avs_s0_byteenable[2] )
											data[wrt_ptr][23:16] <= avs_s0_writedata[23:16]; 	/* Write 3rd byte				 */
							 
										if ( avs_s0_byteenable[3] )
											data[wrt_ptr][31:24] <= avs_s0_writedata[31:24]; 	/* Write 4th byte				 */
									end
								end
					
							if ( avs_s0_read )
								begin						
									slave_waitrequest <= !(|isFound_rd[N-1:0]);					/* Deassert waitrequest if requested data is found in FIFO */
						
									if ( |isFound_rd[N-1:0] ) 
										slave_readdata <= data[find_ptr_rd];					/* Forward requested data from FIFO to SLAVE port 		   */
								end
						end
			
					if ( ongoingrequest && (avm_m0_waitrequest == 0) )							/* Check for end of READ or WRITE transaction 			   */
						begin
							ongoingrequest = 1'b0;
						
							if	( master_read  )												/* READ has finished , forward result to SLAVE port 	   */
								begin
									slave_readdata	  <= avm_m0_readdata;
									slave_waitrequest <= 1'b0;									/* deassert waitrequest */
									master_read		  <= 1'b0; 									/* deassert read        */
									master_chipselect <= 1'b0; 									/* deassert chipselect  */								
								end
						
							if  ( master_write )												/* WRITE has finished   */
								begin
									slave_waitrequest <= 1'b0;									/* deassert waitrequest */
									master_write	  <= 1'b0; 									/* deassert write       */
									master_chipselect <= 1'b0; 									/* deassert chipselect  */
								end						
						end	

				end	/* end of negedge specification */
			
			/* reset */
			
			if ( reset == 0 )
				begin
					fifo_ptr <= N-1;
				
					for(i=0;i<N;i=i+1)
						val[i] <= 4'b0;
						
					ongoingrequest    = 1'b0;
					slave_readdata	  = 32'b0;
					slave_waitrequest = 1'b0;
					master_read		  = 1'b0;
					master_write 	  = 1'b0;
					master_address    = 32'b0;
					master_chipselect = 1'b0;
					master_writedata  = 32'b0;
					master_byteenable = 4'b0;	
				end
		end	/* end of main always */
		
endmodule

					