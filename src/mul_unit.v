`timescale 1ns/1ps

module mul_unit #(parameter EW = 32) (
input op_signed, // 1=signed*signed, 0=unsigned
input [EW-1:0] a,
input [EW-1:0] b,
output [2*EW-1:0] prod
);
reg [2*EW-1:0] prod_r;
assign prod = prod_r;
always @* begin
if (op_signed)
prod_r = $signed(a) * $signed(b);
else
prod_r = a * b;
end
endmodule