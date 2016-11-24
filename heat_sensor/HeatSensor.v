// HeatSensor.v

// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all outputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

`timescale 1 ps / 1 ps
module HeatSensor (
		output wire [31:0] avs_s0_readdata,  //    s0.readdata
		input  wire        avs_s0_write,     //      .write
		input  wire [31:0] avs_s0_writedata, //      .writedata
		input  wire        avs_s0_read,      //      .read
		input  wire        clk,              // clock.clk
		input  wire        reset             // reset.reset
	);

	// TODO: Auto-generated HDL template

	wire [31:0] value;
	reg  [31:0] read_data;
	reg  [21:0] counter;
  	reg  en_heatgen;
	wire en_sensor , reset_sensor, load_sensor;
	
	assign avs_s0_readdata = read_data;//32'b00000000000000000000000000000000;
 
	assign    en_sensor =   counter[21]  &   counter[20];
	assign  load_sensor = (~counter[21]) & (~counter[20]);
	assign reset_sensor =   counter[21]  & (~counter[20]);
	
	always@(posedge load_sensor)
   	  read_data  <= value;
	
	always@(posedge clk or posedge reset)
	  if( reset )
	    en_heatgen <= 1'b0;
	  else if( avs_s0_write )
		 en_heatgen <= avs_s0_writedata[0];
	
	always@(posedge clk or posedge reset)
	  if( reset )
	    counter <= 22'b0;
     else
		 counter <= counter + 1;
 	 
   Sensor        s0 (.en_sensor(en_sensor) , .reset_sensor(reset_sensor) , .value(value) );
   //h0.count = 100;
   HeatGenerator h0 (.enable(en_heatgen));
   HeatGenerator h1 (.enable(en_heatgen));
   HeatGenerator h2 (.enable(en_heatgen));
   HeatGenerator h3 (.enable(en_heatgen));
   HeatGenerator h4 (.enable(en_heatgen));
   HeatGenerator h5 (.enable(en_heatgen));
   HeatGenerator h6 (.enable(en_heatgen));
   HeatGenerator h7 (.enable(en_heatgen));
   HeatGenerator h8 (.enable(en_heatgen));
   HeatGenerator h9 (.enable(en_heatgen));

endmodule

module HeatGenerator(input wire enable);

    parameter count = 50;
    integer i;
  
    reg [count-1:0] ring_osc /* synthesis keep */;

    always@(*)
     for(i=0;i<count;i=i+1)
      begin
       ring_osc[i] = enable&(~ring_osc[i]);
      end
		
endmodule
 
module  Sensor (  
						input  wire    en_sensor,
						input  wire reset_sensor,
						output reg  [31:0] value
               );

    wire signal;					

    always@(posedge signal or posedge reset_sensor)
     	  if(reset_sensor)
	    value <= 0;
	  else 
     	    value <= value + 1;
		
    Ring_Oscilator m0( .enable(en_sensor) , .osc_out(signal) );	 
		 
endmodule						

module Ring_Oscilator (
                         input  wire enable,
								 output wire osc_out
                      );
							 
    integer   i;
	 parameter count = 50;// number should be even
				
    reg [count-1:0] n /* synthesis keep */;
		
	 always@(*)
	  begin
		  n[0] <= enable & n[count-1];  
			
		  for(i=0;i<count-1;i=i+1)
		    begin
		     n[i+1] <= ~n[i];
		    end
	  end
		 
	 assign osc_out = n[count-1];							 
							 
endmodule

