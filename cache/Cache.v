/*  Cache.v
 *
 *  Direct mapped reconfigurable cache 
 *
 *  Author      : Kamyar Mirzazad (kammirzazad@ee.sharif.edu)
 *  Created  On : May 25 , 2014
 *  Modified On : May 29 , 2014
 * 
 *  Notes       :
 *
 *  Main memory size = 512 Mbyte = 128 Mword
 *
 *	 64 Kbit cache size = 2048 word
 *   
 *   line_size | #lines | words per word  
 * ----------------------------------------
 *   00000111  |   256  |     	8 
 *   00001111  |   128  |    	  16 
 *   00011111  |    64  |    	  32
 *   00111111  |    32  |    	  64       
 *   01111111  |    16  |  	 128
 *   11111111  |     8  |  	 256
 *
 *  28 =  1(empty) + 16(tag) + 8(index) + 3(word offset) 
 *          [27]     [26:11]    [10:3]       [2:0]         
 *
 *  tag address -  256 word - 0000 xxxx xxxx
 *  mem address - 2048 word - 1xxx xxxx xxxx
 *
 */

`timescale 1 ps / 1 ps
module Cache #(
		parameter AUTO_CLOCK_CLOCK_RATE = "-1"		
	) (

		input  wire        clk,                // clock.clk
		input  wire        reset,              // reset.reset
	
		input  wire [27:0] avs_s0_address,     //    s0.address		: processor interface
		input  wire        avs_s0_read,        //      .read
		output wire [31:0] avs_s0_readdata,    //      .readdata
		input  wire        avs_s0_write,       //      .write
		input  wire [31:0] avs_s0_writedata,   //      .writedata
		output wire        avs_s0_waitrequest, //      .waitrequest

		input  wire [ 4:0] avs_s1_address,     //    s1.address		: reconfig port
		input  wire        avs_s1_read,        //      .read
		output wire [31:0] avs_s1_readdata,    //      .readdata
		input  wire        avs_s1_write,       //      .write
		input  wire [31:0] avs_s1_writedata,   //      .writedata
		output wire        avs_s1_waitrequest, //      .waitrequest
		
		input  wire [11:0] avs_s2_address,     //    s2.address		: cache interface 
		input  wire        avs_s2_read,        //      .read
		output wire [31:0] avs_s2_readdata,    //      .readdata
		input  wire        avs_s2_write,       //      .write
		input  wire [31:0] avs_s2_writedata,   //      .writedata
		output wire        avs_s2_waitrequest, //      .waitrequest
		
		output wire [27:0] avm_m0_address,     //    m0.address		: memory & cache interface
		output wire        avm_m0_read,        //      .read
		input  wire        avm_m0_waitrequest, //      .waitrequest
		input  wire [31:0] avm_m0_readdata,    //      .readdata
		output wire        avm_m0_write,       //      .write
		output wire [31:0] avm_m0_writedata    //      .writedata
	);
	
	/* CACHE ADDRESSES : 28 bit total word address width - 12 determined by tag & line address => 16 bit addresses */
	parameter CACHE_ADDR_0 				= 16'h8000;
	parameter CACHE_ADDR_1 				= 16'h8001;
	parameter CACHE_ADDR_2 				= 16'h8002;
	parameter CACHE_ADDR_3 				= 16'h8003;
	parameter CACHE_ADDR_4 				= 16'h8004;
	parameter CACHE_ADDR_5 				= 16'h8005;
	parameter CACHE_ADDR_6 				= 16'h8006;
	parameter CACHE_ADDR_7 				= 16'h8007;
	parameter CACHE_ADDR_8 				= 16'h8008;
	parameter CACHE_ADDR_9 				= 16'h8009;
	parameter CACHE_ADDR_10 			= 16'h800A;
	parameter CACHE_ADDR_11 			= 16'h800B;
	parameter CACHE_ADDR_12 			= 16'h800C;
	parameter CACHE_ADDR_13 			= 16'h800D;
	parameter CACHE_ADDR_14 			= 16'h800E;
	parameter CACHE_ADDR_15				= 16'h800F;
	
	/* FSM states */
	
	parameter IDLE							= 4'b0000;
	
	parameter TAG_CHECK_READ			= 4'b0001;
	parameter TAG_CHECK_WRITE			= 4'b0010;		
	parameter WRITE_DATA_TO_CACHE		= 4'b0011;		
	
	parameter ADVANCE_CACHE_PTR		= 4'b0100;
	parameter GET_TAG_FROM_NEIGHBOR	= 4'b0101;
	parameter GET_DATA_FROM_NEIGHBOR	= 4'b0110;			
			
	parameter READ_FROM_MAIN_MEMORY	= 4'b0111;	
	parameter ADVANCE_READ_PTR			= 4'b1000;
	
	parameter WRITE_TO_MAIN_MEMORY	= 4'b1001;	
	parameter ADVANCE_WRITE_PTR		= 4'b1010;
	
	/* cache variables */	
		
	reg  [ 3:0] cache_ptr;		
	reg  [ 3:0] cache_count;	/* maximum number of caches for each cache is 15 */
	reg  [ 3:0] cache_order [3:0];
	wire [15:0] base_address  = 	( cache_order[cache_ptr] == 4'b0000 ) ? CACHE_ADDR_0  :
											( cache_order[cache_ptr] == 4'b0001 ) ? CACHE_ADDR_1  :
											( cache_order[cache_ptr] == 4'b0010 ) ? CACHE_ADDR_2  :	
											( cache_order[cache_ptr] == 4'b0011 ) ? CACHE_ADDR_3  :
											( cache_order[cache_ptr] == 4'b0100 ) ? CACHE_ADDR_4  :
											( cache_order[cache_ptr] == 4'b0101 ) ? CACHE_ADDR_5  :
											( cache_order[cache_ptr] == 4'b0110 ) ? CACHE_ADDR_6  :
											( cache_order[cache_ptr] == 4'b0111 ) ? CACHE_ADDR_7  :
											( cache_order[cache_ptr] == 4'b1000 ) ? CACHE_ADDR_8  :
											( cache_order[cache_ptr] == 4'b1001 ) ? CACHE_ADDR_9  :
											( cache_order[cache_ptr] == 4'b1010 ) ? CACHE_ADDR_10 :
											( cache_order[cache_ptr] == 4'b1011 ) ? CACHE_ADDR_11 :
											( cache_order[cache_ptr] == 4'b1100 ) ? CACHE_ADDR_12 :
											( cache_order[cache_ptr] == 4'b1101 ) ? CACHE_ADDR_13 :
											( cache_order[cache_ptr] == 4'b1110 ) ? CACHE_ADDR_14 :
																								 CACHE_ADDR_15 ;
					
	reg  [ 4:0] line_size;			
	reg  [ 7:0] memory_ptr;	
	reg  [ 3:0] current_state_of_s0 , next_state_of_s0;		
	
	wire [17:0] tag_read_s0   , tag_read_s2;	/* 16(tag) + 1(valid bit) + 1(dirty bit) */	
	wire [31:0] cache_read_s0 , cache_read_s2;																

	wire		   are_all_caches_checked   = ( cache_ptr == cache_count );	
	wire [27:0] cache_tag_address			 =	{ base_address , 1'b0 , 3'b0 , avs_s0_address[10:3] };
	wire [27:0] cache_data_address		 = { base_address , 1'b1 ,        avs_s0_address[10:0] };

	wire 			tag_check_s0 				 = (     tag_read_s0[17:2] == avs_s0_address[26:11] ) && (     tag_read_s0[1] );
	wire 			tag_check_m0 				 = ( avm_m0_readdata[17:2] == avs_s0_address[26:11] ) && ( avm_m0_readdata[1] );
	
	wire 			is_line_dirty 				 =   tag_read_s0[0]; 			
	wire			default_access				 = (  current_state_of_s0 == IDLE					  ) || ( current_state_of_s0 == TAG_CHECK_READ ) || ( current_state_of_s0 == TAG_CHECK_WRITE ) || ( current_state_of_s0 == ADVANCE_READ_PTR );	
	wire			cache_tag_write_enable   = ( (current_state_of_s0 == TAG_CHECK_WRITE		  ) && tag_check_s0        ) ||	 
														( (current_state_of_s0 == READ_FROM_MAIN_MEMORY) && ~avm_m0_waitrequest ); 																
		
	wire [27:0] memory_write_address 	 = ( line_size == 8'b00000111 ) ? { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:3] , memory_ptr[2:0] } :
														( line_size == 8'b00001111 ) ? { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:4] , memory_ptr[3:0] } :
														( line_size == 8'b00011111 ) ? { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:5] , memory_ptr[4:0] } :
														( line_size == 8'b00111111 ) ? { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:6] , memory_ptr[5:0] } :
														( line_size == 8'b01111111 ) ? { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:7] , memory_ptr[6:0] } :
																							    { 1'b0 , tag_read_s0[17:2] , avs_s0_address[10:8] , memory_ptr[7:0] } ;
		
	wire [27:0] memory_read_address  	 = ( line_size == 8'b00000111 ) ? { avs_s0_address[27:3] , memory_ptr[2:0] } :
														( line_size == 8'b00001111 ) ? { avs_s0_address[27:4] , memory_ptr[3:0] } :
														( line_size == 8'b00011111 ) ? { avs_s0_address[27:5] , memory_ptr[4:0] } :
														( line_size == 8'b00111111 ) ? { avs_s0_address[27:6] , memory_ptr[5:0] } :
														( line_size == 8'b01111111 ) ? { avs_s0_address[27:7] , memory_ptr[6:0] } : 
																								 { avs_s0_address[27:8] , memory_ptr[7:0] } ;
	
	wire [ 7:0] read_write_tag_address	 = ( line_size == 8'b00000111 ) ? { avs_s0_address[10:3] 						} :
														( line_size == 8'b00001111 ) ? { avs_s0_address[10:4] , memory_ptr[  3] } :
														( line_size == 8'b00011111 ) ? { avs_s0_address[10:5] , memory_ptr[4:3] } :
														( line_size == 8'b00111111 ) ? { avs_s0_address[10:6] , memory_ptr[5:3] } :
														( line_size == 8'b01111111 ) ? { avs_s0_address[10:7] , memory_ptr[6:3] } :
																								 { avs_s0_address[10:8] , memory_ptr[7:3] } ;																								
																								
	wire [10:0] read_write_cache_address = ( line_size == 8'b00000111 ) ? { avs_s0_address[10:3] , memory_ptr[2:0] } :
														( line_size == 8'b00001111 ) ? { avs_s0_address[10:4] , memory_ptr[3:0] } :
														( line_size == 8'b00011111 ) ? { avs_s0_address[10:5] , memory_ptr[4:0] } :
														( line_size == 8'b00111111 ) ? { avs_s0_address[10:6] , memory_ptr[5:0] } :
														( line_size == 8'b01111111 ) ? { avs_s0_address[10:7] , memory_ptr[6:0] } : 
																								 { avs_s0_address[10:8] , memory_ptr[7:0] } ;	
																								 
	always@(*)
		begin
		
			case (current_state_of_s0)
			
			IDLE:
				begin
					next_state_of_s0 = IDLE;
									
					if( avs_s0_read  )				
						next_state_of_s0 = TAG_CHECK_READ;

					if( avs_s0_write )
						next_state_of_s0 = TAG_CHECK_WRITE;							
				end
		
			TAG_CHECK_READ:
				begin
					if(tag_check_s0)
						next_state_of_s0 = IDLE;
					else
						next_state_of_s0 = ADVANCE_CACHE_PTR;					
				end
				
			TAG_CHECK_WRITE:
				begin
					if(tag_check_s0)
						next_state_of_s0 = WRITE_DATA_TO_CACHE;
					else
						begin
							if( is_line_dirty )
								next_state_of_s0 = WRITE_TO_MAIN_MEMORY;
							else	
								next_state_of_s0 = READ_FROM_MAIN_MEMORY;
						end
				end
							
			WRITE_DATA_TO_CACHE:		next_state_of_s0 = IDLE;				
			
			ADVANCE_CACHE_PTR:
				begin
					if( are_all_caches_checked )
						begin
							if( is_line_dirty )
								next_state_of_s0 = WRITE_TO_MAIN_MEMORY;
							else
								next_state_of_s0 = READ_FROM_MAIN_MEMORY;							
						end
					else
						next_state_of_s0 = GET_TAG_FROM_NEIGHBOR;						
				end
			
			GET_TAG_FROM_NEIGHBOR:
				begin
					if(avm_m0_waitrequest)
						next_state_of_s0 = GET_TAG_FROM_NEIGHBOR;
					else
						begin
							if(tag_check_m0)
								next_state_of_s0 = GET_DATA_FROM_NEIGHBOR;
							else
								next_state_of_s0 = ADVANCE_CACHE_PTR;							
						end	
				end
		
			GET_DATA_FROM_NEIGHBOR:
				begin
					if(avm_m0_waitrequest)
						next_state_of_s0 = GET_DATA_FROM_NEIGHBOR;
					else
						next_state_of_s0 = IDLE;
				end																		
				
			READ_FROM_MAIN_MEMORY:
				begin
					if(avm_m0_waitrequest)
						next_state_of_s0 = READ_FROM_MAIN_MEMORY;
					else
						next_state_of_s0 = ADVANCE_READ_PTR;
				end		
			
			ADVANCE_READ_PTR:
				begin
					if( ( memory_ptr[7:0] & line_size ) == line_size )
						begin
							if( avs_s0_read )
								next_state_of_s0 = TAG_CHECK_READ;			/* filled cache line , now go read data from cache */
							else
								next_state_of_s0 = WRITE_DATA_TO_CACHE;   /* filled cache line , now write incoming word in cache */
						end		
					else
						next_state_of_s0 = READ_FROM_MAIN_MEMORY;
				end
			
			WRITE_TO_MAIN_MEMORY:
				begin
					if(avm_m0_waitrequest)
						next_state_of_s0 = WRITE_TO_MAIN_MEMORY;	
					else
						next_state_of_s0 = ADVANCE_WRITE_PTR;				
				end
				
			ADVANCE_WRITE_PTR:
				begin
					if( ( memory_ptr[7:0] & line_size ) == line_size )
						next_state_of_s0 = READ_FROM_MAIN_MEMORY;	/* finished eviction , now go read data */
					else
						next_state_of_s0 = WRITE_TO_MAIN_MEMORY;
				end
			
			default:
				next_state_of_s0 = IDLE;
			
			endcase			
			
		end																				  
		
	always@( posedge clk )
		begin
		
		   current_state_of_s0 <= next_state_of_s0;
					
			if( current_state_of_s0 == ADVANCE_CACHE_PTR )
				cache_ptr  <= cache_ptr + 1;

			if( (current_state_of_s0 == TAG_CHECK_READ  ) || (current_state_of_s0 == TAG_CHECK_WRITE  ) )
				begin
					cache_ptr  <= 4'b0;
					memory_ptr <= 8'b00000000;	/* this is just for the case that line size changes between two accesses */			
				end
				
			if( (current_state_of_s0 == ADVANCE_READ_PTR) || (current_state_of_s0 == ADVANCE_WRITE_PTR) )
				memory_ptr <= memory_ptr + 1;
								
			if( avs_s1_write )
				begin
					if( avs_s1_address == 5'b0 )
						line_size		 <= avs_s1_writedata[7:0];
				
					if( avs_s1_address == 5'b1 )
						cache_count 	 <= avs_s1_writedata[3:0];															
						
					if( avs_s1_address  > 5'b1 )
						cache_order[avs_s1_address[4:0]-2] <=  avs_s1_writedata[17:0];
				end
																					
			if( reset )
				begin
					line_size	 		  <= 8'b00000111;
					cache_ptr		  	  <= 4'b0;
					cache_count			  <= 4'b0;
					current_state_of_s0 <= IDLE;
				end	
				
		end
		
	CacheMem _CacheMem(
								.address_a( (default_access)? avs_s0_address[10:0] : read_write_cache_address ),								
								.data_a   ( (current_state_of_s0 == TAG_CHECK_WRITE) ? avs_s0_writedata : avm_m0_readdata ),								
								.wren_a   ( cache_tag_write_enable ),
																																
								.address_b(avs_s2_address[10:0]),
								.data_b	 (32'b0),
								.wren_b	 (1'b0),								
								.q_a		 (cache_read_s0),
								.q_b		 (cache_read_s2),
								.clock_a	 (clk),
								.clock_b	 (clk)
							);
					
	TagMem _TagMem		(
								.address_a( (default_access)? avs_s0_address[10:3] : read_write_tag_address   ),																
								.data_a   ( {avs_s0_address[26:11] , 1'b1 , ( current_state_of_s0 == TAG_CHECK_WRITE ) } ),	/* 1'b1 => new line is always valid */							
								.wren_a   (  cache_tag_write_enable ),
								
								.address_b(avs_s2_address[ 7:0]),
								.data_b	 (18'b0),
								.wren_b	 (1'b0),								
								.q_a		 (tag_read_s0),
								.q_b		 (tag_read_s2),
								.clock_a	 (clk),
								.clock_b	 (clk)																
							);
   	
	assign avs_s0_waitrequest = ~( /* wait request is asserted unless controller is in any one of conditions below */										  
										    (   current_state_of_s0 == WRITE_DATA_TO_CACHE     ) || 
										    ( ( current_state_of_s0 == TAG_CHECK_READ 			 ) &&  tag_check_s0 )       ||
											 ( ( current_state_of_s0 == GET_DATA_FROM_NEIGHBOR  ) && ~avm_m0_waitrequest ) || 
										    ( ( current_state_of_s0 == IDLE           			 ) && ~( avs_s0_read || avs_s0_write ) ) 
										  ) ;
										  

	assign avs_s0_readdata	  = ( current_state_of_s0 == GET_DATA_FROM_NEIGHBOR ) ? avm_m0_readdata : cache_read_s0;      
	
	/***************************/
	
	assign avm_m0_writedata   = cache_read_s0; /* for eviction of dirty data */

	assign avm_m0_address 	  = ( current_state_of_s0 == GET_TAG_FROM_NEIGHBOR  ) ?    cache_tag_address  :
										 ( current_state_of_s0 == GET_DATA_FROM_NEIGHBOR ) ?    cache_data_address :
										 ( current_state_of_s0 == READ_FROM_MAIN_MEMORY  ) ?   memory_read_address : 	
																												memory_write_address ;

	assign avm_m0_write   	  = ( current_state_of_s0 == WRITE_TO_MAIN_MEMORY  );

	assign avm_m0_read    	  = ( current_state_of_s0 == GET_TAG_FROM_NEIGHBOR ) || ( current_state_of_s0 == GET_DATA_FROM_NEIGHBOR ) || ( current_state_of_s0 == READ_FROM_MAIN_MEMORY );

	/***************************/
	
	assign avs_s1_waitrequest = 1'b0;	/* config port never asks master to wait */

	assign avs_s1_readdata 	  = ( avs_s1_address == 5'b0 ) ? { 27'b0 , line_size  } :
										 ( avs_s1_address == 5'b1 ) ? { 28'b0 , cache_count} : 32'hFFFFFFFF;
	
	/***************************/
	
	assign avs_s2_waitrequest = 1'b0;	/* interconnect never waits for mem & tag read */

	assign avs_s2_readdata 	  = ( avs_s2_address[11] ) ?  cache_read_s2[31:0] : { 14'b0 , tag_read_s2[17:0] };

endmodule