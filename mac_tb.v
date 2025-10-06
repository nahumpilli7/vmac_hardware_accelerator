`timescale 1ns/1ps

module mac_tb;
  // ---------- Declarations at top (Verilog-2001 safe) ----------
  // Clock & reset
  reg clk = 0;
  reg rst = 1;

  // DUT interface
  reg         in_valid;
  wire        in_ready;
  wire        out_valid;
  reg         out_ready;
  reg  [63:0] a_vec;
  reg  [63:0] b_vec;
  reg [127:0] c_vec;
  reg  [3:0]  lane_mask;    // 1 = bypass C, 0 = MAC
  reg         op_signed;    // 1 = signed, 0 = unsigned
  wire [127:0] y_vec;

  // Per-lane views (y_vec = {y3,y2,y1,y0})
  wire [31:0] y0 = y_vec[ 31:  0];
  wire [31:0] y1 = y_vec[ 63: 32];
  wire [31:0] y2 = y_vec[ 95: 64];
  wire [31:0] y3 = y_vec[127: 96];

  // Counters / misc
  integer pass_cnt = 0;
  integer fail_cnt = 0;
  integer case_id  = 0;
  reg rnd_bp_enable = 1'b0;

  // Random stress temps (declared here, not mid-block)
  integer i;
  reg [63:0]  ra, rb;
  reg [127:0] rc;
  reg [3:0]   rmask;
  reg         rsigned;

  // Clock
  always #2.5 clk = ~clk;  // 200 MHz

  // Instantiate DUT
  mac4x16_top dut (
    .clk(clk), .rst(rst),
    .in_valid(in_valid), .in_ready(in_ready),
    .out_valid(out_valid), .out_ready(out_ready),
    .a_vec(a_vec), .b_vec(b_vec), .c_vec(c_vec),
    .lane_mask(lane_mask), .op_signed(op_signed),
    .y_vec(y_vec)
  );

  // ---------- Small helpers (no indexed part-selects) ----------
  function [15:0] lane16; input [63:0] v; input [1:0] idx;
    begin
      case (idx)
        2'd0: lane16 = v[15:0];
        2'd1: lane16 = v[31:16];
        2'd2: lane16 = v[47:32];
        default: lane16 = v[63:48];
      endcase
    end
  endfunction

  function [31:0] lane32; input [127:0] v; input [1:0] idx;
    begin
      case (idx)
        2'd0: lane32 = v[31:0];
        2'd1: lane32 = v[63:32];
        2'd2: lane32 = v[95:64];
        default: lane32 = v[127:96];
      endcase
    end
  endfunction

  function [31:0] mac_lane_fn;
    input [15:0] a16, b16;
    input [31:0] c32;
    input        maskbit, signed_mode;
    reg  signed [15:0] as, bs;
    reg  signed [31:0] cs, prods;
    reg  [31:0] prod;
    begin
      if (maskbit) begin
        mac_lane_fn = c32;
      end else if (signed_mode) begin
        as = a16; bs = b16; cs = c32;
        prods = $signed(as) * $signed(bs);
        mac_lane_fn = prods + cs; // wrap to 32
      end else begin
        prod = a16 * b16;
        mac_lane_fn = prod + c32; // wrap to 32
      end
    end
  endfunction

  function [127:0] golden_y;
    input [63:0]  a_in, b_in;
    input [127:0] c_in;
    input [3:0]   m_in;
    input         signed_mode;
    reg [31:0] e0,e1,e2,e3;
    begin
      e0 = mac_lane_fn(lane16(a_in,2'd0), lane16(b_in,2'd0), lane32(c_in,2'd0), m_in[0], signed_mode);
      e1 = mac_lane_fn(lane16(a_in,2'd1), lane16(b_in,2'd1), lane32(c_in,2'd1), m_in[1], signed_mode);
      e2 = mac_lane_fn(lane16(a_in,2'd2), lane16(b_in,2'd2), lane32(c_in,2'd2), m_in[2], signed_mode);
      e3 = mac_lane_fn(lane16(a_in,2'd3), lane16(b_in,2'd3), lane32(c_in,2'd3), m_in[3], signed_mode);
      golden_y = {e3,e2,e1,e0};
    end
  endfunction

  task drive_and_check;
    input [63:0]   a_in, b_in;
    input [127:0]  c_in;
    input [3:0]    mask_in;
    input          signed_mode;
    reg   [127:0]  exp_y;
    reg   [31:0]   e0,e1,e2,e3;
    begin
      case_id = case_id + 1;

      a_vec     = a_in;
      b_vec     = b_in;
      c_vec     = c_in;
      lane_mask = mask_in;
      op_signed = signed_mode;

      exp_y = golden_y(a_in,b_in,c_in,mask_in,signed_mode);
      e0 = exp_y[ 31:  0];
      e1 = exp_y[ 63: 32];
      e2 = exp_y[ 95: 64];
      e3 = exp_y[127: 96];

      @(posedge clk); in_valid = 1'b1;
      while (!in_ready) @(posedge clk);
      @(posedge clk); in_valid = 1'b0;

      while (!out_valid) @(posedge clk);
      @(posedge clk);

      if ((y0 !== e0) || (y1 !== e1) || (y2 !== e2) || (y3 !== e3)) begin
        fail_cnt = fail_cnt + 1;
        $display("FAIL #%0d  signed=%0d mask=%b", case_id, signed_mode, mask_in);
        $display("  a=[%0d,%0d,%0d,%0d]",
                 $signed(lane16(a_in,0)),$signed(lane16(a_in,1)),
                 $signed(lane16(a_in,2)),$signed(lane16(a_in,3)));
        $display("  b=[%0d,%0d,%0d,%0d]",
                 $signed(lane16(b_in,0)),$signed(lane16(b_in,1)),
                 $signed(lane16(b_in,2)),$signed(lane16(b_in,3)));
        $display("  c=[%0d,%0d,%0d,%0d]",
                 $signed(lane32(c_in,0)),$signed(lane32(c_in,1)),
                 $signed(lane32(c_in,2)),$signed(lane32(c_in,3)));
        $display("  got y=[%0d,%0d,%0d,%0d]",
                 $signed(y0),$signed(y1),$signed(y2),$signed(y3));
        $display("  exp y=[%0d,%0d,%0d,%0d]\n",
                 $signed(e0),$signed(e1),$signed(e2),$signed(e3));
        $stop;
      end else begin
        pass_cnt = pass_cnt + 1;
        $display("PASS #%0d  signed=%0d mask=%b  y=[%0d,%0d,%0d,%0d]",
                 case_id, signed_mode, mask_in,
                 $signed(y0),$signed(y1),$signed(y2),$signed(y3));
      end
    end
  endtask

  // helper task: take scalars, pack, then call drive_and_check (avoids big concats in call)
  task tc;
    input signed [15:0] a0,a1,a2,a3;
    input signed [15:0] b0,b1,b2,b3;
    input        [31:0] c0,c1,c2,c3;
    input        [3:0]  mask;
    input               signed_mode;
    reg [63:0]  A,B;
    reg [127:0] C;
    begin
      A = {a3[15:0],a2[15:0],a1[15:0],a0[15:0]};
      B = {b3[15:0],b2[15:0],b1[15:0],b0[15:0]};
      C = {c3,c2,c1,c0};
      drive_and_check(A,B,C,mask,signed_mode);
    end
  endtask

  // Optional: random back-pressure
  always @(posedge clk) if (!rst && rnd_bp_enable) begin
    out_ready <= ($random & 32'h3) != 0; // ~66% ready
  end

  // =========================
  // Test sequence
  // =========================
  initial begin
    // Init
    in_valid = 0; out_ready = 1; lane_mask = 4'b0000; op_signed = 0;
    a_vec = 64'd0; b_vec = 64'd0; c_vec = 128'd0;

    // Reset
    repeat (4) @(posedge clk);
    rst = 0;

    // 1) Unsigned, C=0: a=[1,2,3,4], b=[5,6,7,8] -> [5,12,21,32]
    tc( 16'd1,16'd2,16'd3,16'd4,
        16'd5,16'd6,16'd7,16'd8,
        32'd0,32'd0,32'd0,32'd0,
        4'b0000, 1'b0 );

    // 2) Signed with negatives + nonzero C: a=[-1,2,-3,-4], b=[5,-6,7,-8], c=[10,20,30,40]
    tc( -16'sd1, 16'sd2, -16'sd3, -16'sd4,
         16'sd5, -16'sd6, 16'sd7, -16'sd8,
         32'd10, 32'd20, 32'd30, 32'd40,
         4'b0000, 1'b1 );

    // 3) Mask lanes 1 & 3 (bypass): a=[40,30,20,10], b=[5,4,3,2], c=[1,2,3,4], mask=1010
    tc( 16'd40,16'd30,16'd20,16'd10,
        16'd5, 16'd4, 16'd3, 16'd2,
        32'd1, 32'd2, 32'd3, 32'd4,
        4'b1010, 1'b0 );

    // 4) Unsigned extremes & wrap
    tc( 16'hFFFF,16'd1,16'd0,16'd1234,
        16'd2,16'hFFFF,16'd0,16'd5678,
        32'd0,32'd0,32'd0,32'd0,
        4'b0000, 1'b0 );

    // 5) Signed extremes
    tc( 16'sh8000,16'sh7FFF,16'shFFFF,16'sd0,
        16'shFFFF,16'shFFFF,16'sh7FFF,16'sh8000,
        32'sd100,32'sd200,32'sd300,32'sd400,
        4'b0000, 1'b1 );

    // 6) Mask all lanes (expect y=C)
    tc( 16'd11,16'd22,16'd33,16'd44,
        16'd55,16'd66,16'd77,16'd88,
        32'd1, 32'd2, 32'd3, 32'd4,
        4'b1111, 1'b0 );

    // 7) Alternating mask, mixed signs
    tc( -16'sd7, 16'sd6, -16'sd5, 16'sd4,
         16'sd3,-16'sd2, 16'sd1,-16'sd8,
         32'sd10,32'sd20,32'sd30,32'sd40,
         4'b0101, 1'b1 );

    // ---- Randomized stress ----
    $display("\n--- Randomized stress (200 cases, with back-pressure) ---");
    rnd_bp_enable = 1'b1;
    for (i = 0; i < 200; i = i + 1) begin
      ra = {$random,$random};
      rb = {$random,$random};
      rc = { $random, $random, $random, $random };
      case (i % 5)
        0: rmask = 4'b0000;
        1: rmask = 4'b1111;
        default: rmask = $random;
      endcase
      rsigned = $random;

      // Keep field ordering explicit
      ra = { ra[63:48], ra[47:32], ra[31:16], ra[15:0] };
      rb = { rb[63:48], rb[47:32], rb[31:16], rb[15:0] };
      rc = { rc[127:96], rc[95:64], rc[63:32], rc[31:0] };

      drive_and_check(ra, rb, rc, rmask, rsigned);
    end
    rnd_bp_enable = 1'b0;

    $display("\nSUMMARY: PASS=%0d  FAIL=%0d  (total=%0d)",
             pass_cnt, fail_cnt, pass_cnt+fail_cnt);
    if (fail_cnt==0) $display("All tests PASSED.");
    #20 $finish;
  end
endmodule
