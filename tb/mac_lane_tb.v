`timescale 1ns / 1ps

module mac_lane_tb;

  // Parameters
  localparam EW = 16;
  localparam AW = 32;

  // DUT I/O
  reg  clk;
  reg  rst;
  reg  [EW-1:0] a, b;
  reg  [AW-1:0] c;
  reg  lane_mask;
  reg  op_signed;
  wire [AW-1:0] y;

  // Instantiate the MAC lane
  mac_lane #(.EW(EW), .AW(AW)) dut (
    .clk(clk),
    .rst(rst),
    .in_valid(1'b1),
    .in_ready(),
    .a(a),
    .b(b),
    .c(c),
    .lane_mask(lane_mask),
    .op_signed(op_signed),
    .out_valid(),
    .out_ready(1'b1),
    .y(y)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz

  initial begin
    $display("---- MAC Arithmetic Test ----");
    rst = 1; #10;
    rst = 0;

    // ---------- Unsigned tests ----------
    op_signed = 0;
    lane_mask = 0;

    // Test 1: 3 * 4 + 5 = 17
    a = 16'd3; b = 16'd4; c = 32'd5;
    #20 $display("3 * 4 + 5 = %d (Expected 17)", y);

    // Test 2: 10 * 10 + 0 = 100
    a = 16'd10; b = 16'd10; c = 32'd0;
    #20 $display("10 * 10 + 0 = %d (Expected 100)", y);

    // Test 3: 255 * 2 + 1 = 511
    a = 16'd255; b = 16'd2; c = 32'd1;
    #20 $display("255 * 2 + 1 = %d (Expected 511)", y);

    // ---------- Signed tests ----------
    op_signed = 1;
    lane_mask = 0;

    // Test 4: (-3) * 4 + 10 = -2
    a = -16'sd3; b = 16'sd4; c = 32'sd10;
    #20 $display("-3 * 4 + 10 = %d (Expected -2)", $signed(y));

    // Test 5: (-5) * (-5) + 0 = 25
    a = -16'sd5; b = -16'sd5; c = 32'sd0;
    #20 $display("-5 * -5 + 0 = %d (Expected 25)", $signed(y));

    // ---------- Mask test ----------
    lane_mask = 1;  // output = c
    a = 16'd12; b = 16'd3; c = 32'd50;
    #20 $display("Mask active, output = %d (Expected 50)", y);

    #20;
    $display("---- Test Complete ----");
    $finish;
  end

endmodule
