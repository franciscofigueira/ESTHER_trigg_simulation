`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/02/2020 08:48:02 PM
// Design Name: 
// Module Name: CFD_t
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


module CFD_t(
input clk,
input rst,
input trig_en,
input [9:0] delay,
input signed [15:0] level,
input signed [15:0] data,
input [2:0] state,
output signed [15:0] cfd,
output wire cfd_trigg
    );
    
    reg read_en=0,state1=0;
    wire signed [15:0] fifo_out;
    wire [9:0]used;
    fifo_generator_0 fifodelay(
 .clk(clk),
    .srst(!trig_en) ,
    .din(data) ,
    .wr_en(1'b1) ,
    .rd_en(read_en) ,
    .dout(fifo_out),
    .full() ,
    .empty() ,
    .data_count(used),
    .prog_full() 
);
    
    always @(posedge clk) begin
if(trig_en==0)state1<='b0;
else begin
case(state1)
0:begin 
read_en<=0;
if(used>delay) state1<=1'b1;
end
1:begin
read_en<=1'b1;
end
endcase
end
end

wire signed [31:0] adc_mean_a_negative, CFDa,adc_half;
assign adc_half=data>>1;
assign adc_mean_a_negative=(-adc_half);
assign CFDa= fifo_out+adc_mean_a_negative;
assign cfd= CFDa;

reg cfdton=0, CFD_trigg=0;
assign cfd_trigg=CFD_trigg;
always @(posedge clk)begin
if(CFDa<(-'d50)&&state>3'b001) cfdton<=1'b1;
if(cfdton==1'b1)begin
if(CFDa>(level))begin 
CFD_trigg<=1'b1;
cfdton<=1'b0;
end
end
end

endmodule
