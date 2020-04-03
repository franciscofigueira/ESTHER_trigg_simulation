`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/27/2020 02:32:53 PM
// Design Name: 
// Module Name: esther_trigg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module esther_trigg#(
  parameter     ADC_DATA_WIDTH = 16)  // ADC is 14 bit, but data is 16
  (
    input clk,      // 125 Mhz , two samples per clock
    input [31:0] adc_data_a,
    input adc_enable_a,
    input adc_valid_a,
    input [31:0] adc_data_b,
    input adc_enable_b,
    input adc_valid_b,
    input [31:0] adc_data_c,
    input adc_enable_c,
    input adc_valid_c,
    input [31:0] adc_data_d,
    input adc_enable_d,
    input adc_valid_d,
    
    input trig_enable,  // Enable/Reset State Machine
    input  [47:0] trig_level_arr, // 3 trigger levels
    //input  [1:0]   trig_level_addr,
    //input  trig_level_wrt, // registers write enable
    //input  [15:0] trig_level_data,

    output [15:0] pulse_delay,  // Diference Pulse_0 -> Pulse_1 
    output trigger0,
    output trigger1,
    input [9:0] fifo_used,
    output wire signed [15:0] out_test,
    output CFD_trigger
    );
/*********** Function Declarations ***************/

function signed [ADC_DATA_WIDTH:0] adc_channel_mean_f;  // 17 bit for sum headroom
	 input [ADC_DATA_WIDTH-1:0] adc_data_first;
	 input [ADC_DATA_WIDTH-1:0] adc_data_second;
	 
     reg signed [ADC_DATA_WIDTH:0] adc_ext_1st; 
     reg signed [ADC_DATA_WIDTH:0] adc_ext_2nd; 
	   begin 	
            adc_ext_1st = $signed({adc_data_first[ADC_DATA_WIDTH-1],  adc_data_first}); // sign extend
            adc_ext_2nd = $signed({adc_data_second[ADC_DATA_WIDTH-1], adc_data_second}); 
            adc_channel_mean_f = adc_ext_1st + adc_ext_2nd;
	  end 
  endfunction

function  trigger_rising_eval_f;
	input signed [ADC_DATA_WIDTH:0] adc_channel_mean;
	input signed [ADC_DATA_WIDTH-1:0] trig_lvl;
    
    reg signed [ADC_DATA_WIDTH:0] trig_lvl_ext; 
	begin 
       trig_lvl_ext          = $signed({trig_lvl, 1'b0}); // Mult * 2 with sign 
       trigger_rising_eval_f =(adc_channel_mean > trig_lvl_ext)? 1'b1: 1'b0;
    end 
endfunction

function  trigger_falling_eval_f;
	input signed [ADC_DATA_WIDTH:0] adc_channel_mean;
	input signed [ADC_DATA_WIDTH-1:0] trig_lvl;
	
	reg signed [ADC_DATA_WIDTH:0] trig_lvl_ext; 
	begin 	
        trig_lvl_ext = $signed({trig_lvl, 1'b0}); // Mult * 2  with  sign extend
        trigger_falling_eval_f =(adc_channel_mean < trig_lvl_ext)? 1'b1: 1'b0;
    end 
endfunction


parameter delay=100;
function timing_calculation;
     input [31:0] timer1;
     input [31:0] timer2;
     input [31:0] count;
     
       reg [31:0] avg_time;
       begin
         avg_time=(timer1+timer2)>>1;
      
         timing_calculation=((avg_time-delay) >= count)?1'b1:1'b0;
     end
     
 endfunction     
/*********** End Function Declarations ***************/

/************ Trigger Logic ************/
	/* ADC Data comes in pairs. Compute mean, or this case simply add */
	reg signed [ADC_DATA_WIDTH:0] adc_mean_a, adc_mean_b, adc_mean_c, adc_mean_d ;
	always @(posedge clk) begin
         if (adc_enable_a)  // Use adc_valid_a ?
            adc_mean_a <= adc_channel_mean_f(adc_data_a[15:0], adc_data_a[31:16]); // check order (not really necessary, its a mean...)
         if (adc_enable_b)  // Use adc_valid_b ?
            adc_mean_b <= adc_channel_mean_f(adc_data_b[15:0], adc_data_b[31:16]); 
         if (adc_enable_c)  
            adc_mean_c <= adc_channel_mean_f(adc_data_c[15:0], adc_data_c[31:16]); 
         if (adc_enable_d)  
            adc_mean_d <= adc_channel_mean_f(adc_data_d[15:0], adc_data_d[31:16]); 
	end

	reg  trigger0_r=0;
    assign trigger0 = trigger0_r; 
    
	reg  trigger1_r = 0;
    assign trigger1 = trigger1_r; 
/*
    reg  signed [15:0]  trig_level_a_reg=0;       
    reg  signed [15:0]  trig_level_b_reg=0;       
    reg  signed [15:0]  trig_level_c_reg=0;   
 */   
    wire  signed [15:0]  trig_level_a = trig_level_arr[15:0]; 
    wire  signed [15:0]  trig_level_b = trig_level_arr[31:16]; 
    wire  signed [15:0]  trig_level_c = trig_level_arr[47:32];         
    
     reg [15:0] pulse_delay_r=0;
     assign pulse_delay = pulse_delay_r;
    
	 localparam IDLE    = 3'b000;
     localparam READY   = 3'b001;
     localparam PULSE0  = 3'b010;
     localparam PULSE1  = 3'b011;
     localparam PULSE2  = 3'b100;
     localparam TRIGGER = 3'b101;
     
     localparam WAIT_WIDTH = 24;
     
     reg [WAIT_WIDTH-1:0] wait_cnt = 0; // {WAIT_WIDTH{1'b1}}
 
    // (* mark_debug = "true" *) 
    reg [2:0] state = IDLE;
  /*   
    always @(posedge clk)
       if (!trig_enable) begin
          state <= IDLE;
          trigger0_r  <=  0; 
          trigger1_r  <=  0; 
          wait_cnt <= 24'd37000; //* 8ns Initial Idle Time  = 0.3 ms , Max 16777215 134 ms
          pulse_delay_r  <=  16'hFFFF; 
      
       end
       else
          case (state)
             IDLE: begin        // Sleeping 
                trigger0_r  <=  0; 
                trigger1_r  <=  0; 
                wait_cnt <= wait_cnt - 1;
                if (wait_cnt == {WAIT_WIDTH{1'b0}})
                   state <= READY;
             end
             READY: begin // Armed: Waiting first pulse
                if (trigger_rising_eval_f(adc_mean_a, trig_level_a)) begin 
                   state <= PULSE0;
                   trigger0_r  <=  1'b1; 
                end   
    //            trigger1_r  <=  0; 
                wait_cnt <= 0;
             end
             PULSE0 : begin // Got first pulse. Waiting Second
      //          trigger0_r <=  1'b0; 
//                if (trigger_falling_eval_f(adc_mean_b, trig_level_b_reg)) begin // Testing  negative edge of input b
               
                if (trigger_falling_eval_f(adc_mean_a, trig_level_b)) begin // Testing  negative edge of input b
                    state <= PULSE1;
                    pulse_delay_r  <=  wait_cnt[15:0]; // Save waiting Time
                end
                else 
                    wait_cnt   <=  wait_cnt + 8'd5; // increase 5 time units
             end
             PULSE1 : begin   // Waiting Third Pulse 
                if (trigger_rising_eval_f(adc_mean_a, trig_level_c)) begin 
                    trigger1_r <=  1'b1; 
                    state <= PULSE2;
                end   
             end
             PULSE2 : begin   // Got Third pulse. Waiting calculated delay
                if (wait_cnt == {WAIT_WIDTH{1'b0}}) begin
                   trigger1_r <=  1'b0; 
                   state <= TRIGGER;
                end
                else
                    wait_cnt <= wait_cnt - 1;
             end
             TRIGGER : begin // End Trigger
                trigger0_r <=  1'b1; 
 //                    state <= IDLE;
             end
             default :  
                     state <= IDLE;
          endcase
*/
CFD_t channel_A(
 .clk(clk),
 .rst(),
 .trig_en(trig_enable),
 .delay(fifo_used),
 .level(-'d10),
 .data(adc_mean_a),
 .state(state),
 .cfd(out_test),
 .cfd_trigg(CFD_trigger)
);
/*
reg read_en=0,state1=0;
wire fifo_set;
wire signed [15:0] fifo_out;
wire [9:0]used;
fifo_generator_0 fifodelay(
 .clk(clk),
    .srst(!trig_enable) ,
    .din(adc_mean_a) ,
    .wr_en(1'b1) ,
    .rd_en(read_en) ,
    .dout(fifo_out),
    .full() ,
    .empty() ,
    .data_count(used),
    .prog_full(fifo_set) 
);
always @(posedge clk) begin
if(trig_enable==0)state1<='b0;
else begin
case(state1)
0:begin 
read_en<=0;
if(used>fifo_used) state1<=1'b1;
end
1:begin
read_en<=1'b1;
end
endcase
end
end

wire signed [31:0] adc_mean_a_negative, CFDa,adc_half;
assign adc_half=adc_mean_a>>1;
assign adc_mean_a_negative=(-adc_half);
assign CFDa= fifo_out+adc_mean_a_negative;
assign out_test= CFDa;

reg cfdton=0, CFD_trigg=0;
assign CFD_trigger=CFD_trigg;
always @(posedge clk)begin
if(CFDa<(-'d50)&&state>3'b001) cfdton<=1'b1;
if(cfdton==1'b1)begin
if(CFDa>(-'d10))begin 
CFD_trigg<=1'b1;
cfdton<=1'b0;
end
end
end
*/

reg [31:0] wait_cnt2=0,counter=0;

 always @(posedge clk)
       if (!trig_enable) begin
          state <= IDLE;
          trigger0_r  <=  0; 
          trigger1_r  <=  0; 
          wait_cnt <= 24'd37000; //* 8ns Initial Idle Time  = 0.3 ms , Max 16777215 134 ms
          pulse_delay_r  <=  16'hFFFF; 
      
       end
       else
          case (state)
             IDLE: begin        // Sleeping 
                trigger0_r  <=  0; 
                trigger1_r  <=  0; 
                wait_cnt <= wait_cnt - 1;
                if (wait_cnt == {WAIT_WIDTH{1'b0}})
                   state <= READY;
             end
             READY: begin // Armed: Waiting first pulse
                if (trigger_rising_eval_f(adc_mean_a, trig_level_a)) begin 
                   state <= PULSE0;
                   trigger0_r  <=  1'b1; 
                end   
    //            trigger1_r  <=  0; 
                wait_cnt <= 0;
             end
             PULSE0 : begin // Got first pulse. Waiting Second
      //          trigger0_r <=  1'b0; 
//                if (trigger_falling_eval_f(adc_mean_b, trig_level_b_reg)) begin // Testing  negative edge of input b
               
                if (trigger_rising_eval_f(adc_mean_b, trig_level_a))begin // Testing  negative edge of input b
                    state <= PULSE1;
                    pulse_delay_r  <=  wait_cnt[15:0];  // Save waiting Time
                    wait_cnt2 <= 'b0;
                end
                else 
                    wait_cnt   <=  wait_cnt + 8'd5; // increase 5 time units
             end
             PULSE1 : begin   // Waiting Third Pulse 
                if (trigger_rising_eval_f(adc_mean_c, trig_level_c)) begin 
                    trigger1_r <=  1'b0; 
                    state <= PULSE2;
                    counter<='b0;
                    
                end  
               wait_cnt2<=wait_cnt2+8'd5;
             
                 
             end
             PULSE2 : begin   // Got Third pulse. Waiting calculated delay
                if (wait_cnt == counter) begin
                   trigger1_r <=  1'b0; 
                   state <= TRIGGER;
                end
                else
                    counter<=counter+8'd5;
             end
             TRIGGER : begin // End Trigger
                trigger0_r <=  1'b1; 
                trigger1_r <=  1'b1;
 //                    state <= IDLE;
             end
             default :  
                     state <= IDLE;
          endcase

/*
// Write Trigger Level Registers
   always @(posedge clk)
        if (trig_level_wrt)
                 case (trig_level_addr)
 //                   2'b00:  
                    2'b01: trig_level_a_reg  <=  trig_level_data; 
                    2'b10: trig_level_b_reg  <=  trig_level_data; 
                    2'b11: trig_level_c_reg  <=  trig_level_data; 
                    //                    2'b11:
                    default : ;  
                 endcase
    */                       
	
endmodule
