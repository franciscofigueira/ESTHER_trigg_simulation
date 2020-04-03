`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/27/2020 02:37:09 PM
// Design Name: 
// Module Name: trigg_tb
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


module trigg_tb #(
parameter delay_a='h12c ,
parameter  level_a=-'d10)
();
    
    wire [15:0] pulse_delay;
    wire trigger0,trigger1;
    
    reg clk=1'b1, adc_enable_a, adc_enable_b,adc_enable_c ,adc_enable_d, trig_enable;
    reg signed [31:0] adc_data_a, adc_data_b, adc_data_c, adc_data_d;
   wire [47:0] trig_lvl;
    
    wire CFD_trigger;
    reg [9:0] fifo_used=0;
     reg  signed [15:0]  trig_level_a,trig_level_b,trig_level_c ; 
 wire signed [15:0] CFD;
   assign trig_lvl [15:0] =trig_level_a;
   assign trig_lvl [31:16] =trig_level_b;
   assign trig_lvl [47:32] =trig_level_c;
  
 
    esther_trigg #(
    .ADC_DATA_WIDTH(16))
    dut(
       .clk(clk),      // 125 Mhz , two samples per clock
    .adc_data_a(adc_data_a),
    .adc_enable_a(adc_enable_a),
    .adc_valid_a(),
    .adc_data_b(adc_data_b),
   .adc_enable_b(adc_enable_b),
   .adc_valid_b(),
    .adc_data_c(adc_data_c),
   .adc_enable_c(adc_enable_c),
   .adc_valid_c(),
    .adc_data_d(adc_data_d),
   .adc_enable_d(adc_enable_d),
    .adc_valid_d(),
    
    .trig_enable(trig_enable),  // Enable/Reset State Machine
    .trig_level_arr(trig_lvl), // 3 trigger levels
    //input  [1:0]   trig_level_addr,
    //input  trig_level_wrt, // registers write enable
    //input  [15:0] trig_level_data,

    .pulse_delay(pulse_delay),  // Diference Pulse_0 -> Pulse_1 
    .trigger0(trigger0),
    .trigger1(trigger1),
    .fifo_used(300),
    .out_test(CFD),
    .CFD_trigger(CFD_trigger)
    );
   
    reg signed [13:0] ram [0:22500];
    reg signed [13:0] ramb [0:22500];
    reg signed [13:0] ramc [0:22500];
    reg signed [10:0] subt=0;
    reg [31:0] sup=0;
    always #1 clk=!clk;
    always #2 begin
    adc_data_a=(ram[sup]+subt);
    adc_data_b<=ramb[sup]+subt;
    adc_data_c<=ramc[sup]+subt;
    sup<=sup+1'b1;
    end
    
    initial begin
    trig_level_a=100;
    trig_level_b=100;
    trig_level_c=100;
    subt=-'h64;
    adc_enable_a=1;
    adc_enable_b=1;
    adc_enable_c=1;
      adc_enable_d=1;
      fifo_used=300;
    $readmemh("atest.data", ram);
    $readmemh("btest.data", ramb);
    $readmemh("ctest.data", ramc);
    #1 trig_enable=1;
  
    
    end
endmodule
