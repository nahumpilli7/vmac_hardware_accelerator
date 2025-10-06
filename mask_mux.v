`timescale 1ns / 1ps

module mask_mux #(parameter W = 64) (
input mask,
input [W-1:0] c,
input [W-1:0] mac_sum,
output [W-1:0] y
);
assign y = mask ? c : mac_sum;
endmodule