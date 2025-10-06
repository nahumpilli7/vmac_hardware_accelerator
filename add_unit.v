`timescale 1ns / 1ps

module add_unit #(parameter W = 64) (
input [W-1:0] x,
input [W-1:0] y,
output [W-1:0] sum
);
assign sum = x + y;
endmodule