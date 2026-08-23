`timescale 1ns/1ps
// Self-checking scoreboard testbench for mac4x16_top.
// Independent producer/consumer with random back-pressure on BOTH sides.
// The consumer owns out_ready, so results never race against in-flight vectors.
// Exit code: $finish(0) on all-pass, $fatal/non-zero on any mismatch (CI-friendly).
module mac_tb;
  localparam int N_RANDOM = 500;

  reg clk = 0, rst = 1;
  reg         in_valid = 0;  wire in_ready;
  wire        out_valid;     reg  out_ready = 0;
  reg  [63:0] a_vec, b_vec;  reg [127:0] c_vec;
  reg  [3:0]  lane_mask;     reg  op_signed;
  wire [127:0] y_vec;

  always #2.5 clk = ~clk;   // 200 MHz

  mac4x16_top dut (
    .clk(clk), .rst(rst),
    .in_valid(in_valid), .in_ready(in_ready),
    .out_valid(out_valid), .out_ready(out_ready),
    .a_vec(a_vec), .b_vec(b_vec), .c_vec(c_vec),
    .lane_mask(lane_mask), .op_signed(op_signed), .y_vec(y_vec)
  );

  // ---------- Independent golden model ----------
  function [31:0] lane_mac(input [15:0] a, input [15:0] b, input [31:0] c,
                           input m, input sg);
    reg signed [31:0] p;
    begin
      if (m)            lane_mac = c;               // mask => bypass C
      else if (sg)      begin p = $signed(a) * $signed(b); lane_mac = p + $signed(c); end
      else              lane_mac = (a * b) + c;     // wrap to 32
    end
  endfunction
  function [127:0] gold(input [63:0] A, input [63:0] B, input [127:0] C,
                        input [3:0] M, input sg);
    begin
      gold = { lane_mac(A[63:48],B[63:48],C[127:96],M[3],sg),
               lane_mac(A[47:32],B[47:32],C[ 95:64],M[2],sg),
               lane_mac(A[31:16],B[31:16],C[ 63:32],M[1],sg),
               lane_mac(A[15: 0],B[15: 0],C[ 31: 0],M[0],sg) };
    end
  endfunction

  // ---------- Expected-result FIFO (in-order) ----------
  reg [127:0] exp_q [0:8191];
  integer wr = 0, rd = 0;
  integer errors = 0, checked = 0, i;

  // ---------- Directed corner cases, applied through the same producer path ----------
  // Queued as stimulus; the producer FSM streams them, then random cases follow.
  reg  [63:0]  dA [0:6];
  reg  [63:0]  dB [0:6];
  reg [127:0]  dC [0:6];
  reg  [3:0]   dM [0:6];
  reg          dS [0:6];
  integer dcount = 7, dsent = 0;
  initial begin
    // 1) unsigned, C=0
    dA[0]={16'd4,16'd3,16'd2,16'd1};      dB[0]={16'd8,16'd7,16'd6,16'd5};      dC[0]=0;                                            dM[0]=4'b0000; dS[0]=0;
    // 2) signed w/ negatives + nonzero C
    dA[1]={-16'sd4,-16'sd3,16'sd2,-16'sd1};dB[1]={-16'sd8,16'sd7,-16'sd6,16'sd5};dC[1]={32'sd40,32'sd30,32'sd20,32'sd10};             dM[1]=4'b0000; dS[1]=1;
    // 3) partial mask
    dA[2]={16'd10,16'd20,16'd30,16'd40};  dB[2]={16'd2,16'd3,16'd4,16'd5};      dC[2]={32'd4,32'd3,32'd2,32'd1};                     dM[2]=4'b1010; dS[2]=0;
    // 4) unsigned extremes / wrap
    dA[3]={16'd1234,16'd0,16'd1,16'hFFFF};dB[3]={16'd5678,16'd0,16'hFFFF,16'd2};dC[3]=0;                                            dM[3]=4'b0000; dS[3]=0;
    // 5) signed extremes
    dA[4]={16'sd0,16'shFFFF,16'sh7FFF,16'sh8000}; dB[4]={16'sh8000,16'sh7FFF,16'shFFFF,16'shFFFF}; dC[4]={32'sd400,32'sd300,32'sd200,32'sd100}; dM[4]=4'b0000; dS[4]=1;
    // 6) mask all
    dA[5]={16'd44,16'd33,16'd22,16'd11};  dB[5]={16'd88,16'd77,16'd66,16'd55};  dC[5]={32'd4,32'd3,32'd2,32'd1};                     dM[5]=4'b1111; dS[5]=0;
    // 7) alternating mask, mixed signs
    dA[6]={16'sd4,-16'sd5,16'sd6,-16'sd7};dB[6]={-16'sd8,16'sd1,-16'sd2,16'sd3};dC[6]={32'sd40,32'sd30,32'sd20,32'sd10};             dM[6]=4'b0101; dS[6]=1;
  end

  // ---------- Producer ----------
  reg producing_random = 0;
  always @(posedge clk) if (!rst) begin
    if (in_valid && in_ready) begin
      exp_q[wr] <= gold(a_vec,b_vec,c_vec,lane_mask,op_signed);
      wr <= wr + 1;
    end
    // choose next stimulus when the current beat is (about to be) accepted or bus idle
    if (!in_valid || (in_valid && in_ready)) begin
      if (dsent < dcount) begin
        a_vec<=dA[dsent]; b_vec<=dB[dsent]; c_vec<=dC[dsent];
        lane_mask<=dM[dsent]; op_signed<=dS[dsent];
        in_valid<=1; dsent<=dsent+1;
      end else if (wr < (dcount + N_RANDOM)) begin
        a_vec<={$random,$random}; b_vec<={$random,$random};
        c_vec<={$random,$random,$random,$random};
        lane_mask<=$random; op_signed<=$random;
        in_valid<=(($random%10)!=0);   // ~90% offer, exercises idle gaps too
        producing_random<=1;
      end else begin
        in_valid<=0;                    // done offering
      end
    end
  end

  // ---------- Consumer (owns back-pressure) + checker ----------
  always @(posedge clk) if (!rst) begin
    out_ready <= (($random%10)!=0);     // ~90% ready, random stalls
    if (out_valid && out_ready) begin
      checked <= checked + 1;
      if (y_vec !== exp_q[rd]) begin
        errors <= errors + 1;
        if (errors < 5)
          $display("FAIL beat #%0d: got=%h exp=%h", rd, y_vec, exp_q[rd]);
      end
      rd <= rd + 1;
    end
  end

  // ---------- Run control ----------
  integer guard = 0;
  initial begin
    repeat (5) @(posedge clk); rst = 0;
    // wait until every offered beat has been produced AND consumed
    while (!(dsent>=dcount && wr>=(dcount+N_RANDOM) && rd>=wr)) begin
      @(posedge clk);
      guard = guard + 1;
      if (guard > 200000) begin
        $display("TIMEOUT: rd=%0d wr=%0d", rd, wr); $fatal(1);
      end
    end
    $display("SUMMARY: checked=%0d errors=%0d (directed=%0d + random=%0d)",
             checked, errors, dcount, N_RANDOM);
    if (errors == 0) begin
      $display("ALL TESTS PASSED"); $finish;
    end else begin
      $display("TESTS FAILED: %0d mismatches", errors); $fatal(1);
    end
  end
endmodule
