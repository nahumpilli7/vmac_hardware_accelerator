`timescale 1ns/1ps

module mac_tb;
  localparam QUEUE_DEPTH = 4096;
  localparam RANDOM_CYCLES = 2000;
  reg clk = 0, rst = 1, in_valid = 0, out_ready = 0;
  wire in_ready, out_valid;
  reg [63:0] a_vec = 0, b_vec = 0;
  reg [127:0] c_vec = 0;
  reg [3:0] lane_mask = 0;
  reg op_signed = 0;
  wire [127:0] y_vec;
  reg [127:0] expected_q [0:QUEUE_DEPTH-1];
  integer wr_ptr = 0, rd_ptr = 0, accepted = 0, checked = 0, failures = 0;
  integer seed = 32'h51a7c0de;
  integer cycle, drain_timeout;

  always #2.5 clk = ~clk;
  mac4x16_top dut (
    .clk(clk), .rst(rst), .in_valid(in_valid), .in_ready(in_ready),
    .out_valid(out_valid), .out_ready(out_ready), .a_vec(a_vec),
    .b_vec(b_vec), .c_vec(c_vec), .lane_mask(lane_mask),
    .op_signed(op_signed), .y_vec(y_vec)
  );

  function [31:0] lane_expected;
    input [15:0] a, b;
    input [31:0] c;
    input mask, signed_mode;
    reg signed [15:0] sa, sb;
    reg signed [31:0] sc, signed_product;
    reg [31:0] unsigned_product;
    begin
      sa = a; sb = b; sc = c;
      if (mask) lane_expected = c;
      else if (signed_mode) begin
        signed_product = sa * sb;
        lane_expected = signed_product + sc;
      end else begin
        unsigned_product = a * b;
        lane_expected = unsigned_product + c;
      end
    end
  endfunction

  function [127:0] expected_vector;
    input [63:0] a, b;
    input [127:0] c;
    input [3:0] mask;
    input signed_mode;
    begin
      expected_vector = {
        lane_expected(a[63:48],b[63:48],c[127:96],mask[3],signed_mode),
        lane_expected(a[47:32],b[47:32],c[95:64],mask[2],signed_mode),
        lane_expected(a[31:16],b[31:16],c[63:32],mask[1],signed_mode),
        lane_expected(a[15:0],b[15:0],c[31:0],mask[0],signed_mode)
      };
    end
  endfunction

  task load_random_transaction;
    begin
      a_vec = {$random(seed),$random(seed)};
      b_vec = {$random(seed),$random(seed)};
      c_vec = {$random(seed),$random(seed),$random(seed),$random(seed)};
      lane_mask = $random(seed);
      op_signed = $random(seed);
    end
  endtask

  always @(posedge clk) if (!rst) begin
    if (in_valid && in_ready) begin
      if (wr_ptr >= QUEUE_DEPTH) $fatal(1,"Scoreboard overflow");
      expected_q[wr_ptr] = expected_vector(a_vec,b_vec,c_vec,lane_mask,op_signed);
      wr_ptr = wr_ptr + 1; accepted = accepted + 1;
    end
    if (out_valid && out_ready) begin
      if (rd_ptr >= wr_ptr) begin
        failures = failures + 1;
        $display("FAIL: unmatched output");
      end else if (y_vec !== expected_q[rd_ptr]) begin
        failures = failures + 1;
        $display("FAIL #%0d got=%032h expected=%032h",rd_ptr+1,y_vec,expected_q[rd_ptr]);
      end
      rd_ptr = rd_ptr + 1; checked = checked + 1;
    end
  end

  initial begin
    repeat (4) @(posedge clk);
    @(negedge clk); rst = 0; in_valid = 1; out_ready = 1;
    a_vec={16'd4,16'd3,16'd2,16'd1}; b_vec={16'd8,16'd7,16'd6,16'd5};
    c_vec=0; lane_mask=0; op_signed=0;
    @(negedge clk);
    a_vec={16'sd4,-16'sd3,16'sd2,-16'sd1}; b_vec={-16'sd8,16'sd7,-16'sd6,16'sd5};
    c_vec={32'd40,32'd30,32'd20,32'd10}; lane_mask=0; op_signed=1;
    @(negedge clk);
    a_vec=64'hffff_8000_7fff_0000; b_vec=64'h0002_ffff_8000_ffff;
    c_vec=128'hffff_ffff_8000_0000_7fff_ffff_0000_0001; lane_mask=4'b1010; op_signed=1;
    @(negedge clk);

    for (cycle=0; cycle<RANDOM_CYCLES; cycle=cycle+1) begin
      out_ready = (($random(seed)&3)!=0);
      if (!in_valid || in_ready) begin
        in_valid = (($random(seed)&3)!=0);
        if (in_valid) load_random_transaction();
      end
      @(negedge clk);
    end
    in_valid=0; out_ready=1; drain_timeout=0;
    while ((checked<accepted)&&(drain_timeout<20)) begin
      @(negedge clk); drain_timeout=drain_timeout+1;
    end
    if (checked!=accepted) begin
      failures=failures+1;
      $display("FAIL: pipeline did not drain accepted=%0d checked=%0d",accepted,checked);
    end
    $display("SUMMARY: ACCEPTED=%0d CHECKED=%0d FAIL=%0d",accepted,checked,failures);
    if (failures!=0) $fatal(1,"VMAC regression failed");
    $display("ALL TESTS PASSED");
    $finish;
  end
endmodule
