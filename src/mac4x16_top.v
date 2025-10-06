`timescale 1ns / 1ps

module mac4x16_top (
input clk,
input rst,
input in_valid,
output in_ready,
output out_valid,
input out_ready,
input [63:0] a_vec, //4×16 = 64 bits {a3,a2,a1,a0}
input [63:0] b_vec, //4×16 = 64 bits {b3,b2,b1,b0}
input [127:0] c_vec, //4×32 = 128 bits {c3,c2,c1,c0}
input [3:0] lane_mask,
input op_signed,
output [127:0] y_vec //4×32 = 128 bits {y3,y2,y1,y0}
);
//Slice per lane
wire [15:0] a0=a_vec[15:0], a1=a_vec[31:16], a2=a_vec[47:32], a3=a_vec[63:48];
wire [15:0] b0=b_vec[15:0], b1=b_vec[31:16], b2=b_vec[47:32], b3=b_vec[63:48];
wire [31:0] c0=c_vec[31:0], c1=c_vec[63:32], c2=c_vec[95:64], c3=c_vec[127:96];


wire [31:0] y0,y1,y2,y3; wire ir0,ir1,ir2,ir3; wire ov0,ov1,ov2,ov3;


mac_lane #(.EW(16), .AW(32)) L0 (
.clk(clk),.rst(rst), .in_valid(in_valid),.in_ready(ir0),
.a(a0),.b(b0),.c(c0), .lane_mask(lane_mask[0]),.op_signed(op_signed),
.out_valid(ov0),.out_ready(out_ready), .y(y0)
);
mac_lane #(.EW(16), .AW(32)) L1 (
.clk(clk),.rst(rst), .in_valid(in_valid),.in_ready(ir1),
.a(a1),.b(b1),.c(c1), .lane_mask(lane_mask[1]),.op_signed(op_signed),
.out_valid(ov1),.out_ready(out_ready), .y(y1)
);
mac_lane #(.EW(16), .AW(32)) L2 (
.clk(clk),.rst(rst), .in_valid(in_valid),.in_ready(ir2),
.a(a2),.b(b2),.c(c2), .lane_mask(lane_mask[2]),.op_signed(op_signed),
.out_valid(ov2),.out_ready(out_ready), .y(y2)
);
mac_lane #(.EW(16), .AW(32)) L3 (
.clk(clk),.rst(rst), .in_valid(in_valid),.in_ready(ir3),
.a(a3),.b(b3),.c(c3), .lane_mask(lane_mask[3]),.op_signed(op_signed),
.out_valid(ov3),.out_ready(out_ready), .y(y3)
);


assign in_ready = ir0 & ir1 & ir2 & ir3;
assign out_valid = ov0 & ov1 & ov2 & ov3;
assign y_vec = {y3,y2,y1,y0};
endmodule