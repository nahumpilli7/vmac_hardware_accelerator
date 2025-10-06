`timescale 1ns/1ps

module extend_unit #(parameter INW = 64, parameter OUTW = 64) (
input op_signed,
input [INW-1:0] in_val,
output [OUTW-1:0] out_val
);
wire sign_bit = op_signed ? in_val[INW-1] : 1'b0;
generate
if (OUTW >= INW) begin : G_EXT
assign out_val = {{(OUTW-INW){sign_bit}}, in_val};
end else begin : G_TRUNC
assign out_val = in_val[OUTW-1:0];
end
endgenerate
endmodule