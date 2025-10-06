//  - EW=16 (element width), AW=32 (accumulator/result width)
//  - 2-stage pipeline (input regs -> DSP MAC -> output reg)
//  - Pre-extend once (signed/unsigned), single (A*B)+C expression => 1 DSP/lane
//  - Mask bypass happens after the MAC.
module mac_lane #(parameter EW = 16, parameter AW = 32) (
  input                    clk,
  input                    rst,

  //Handshake in
  input                    in_valid,
  output                   in_ready,

  //Lane data
  input      [EW-1:0]      a,
  input      [EW-1:0]      b,
  input      [AW-1:0]      c,
  input                    lane_mask,
  input                    op_signed,   // 1 = signed, 0 = unsigned

  //Handshake out
  output                   out_valid,
  input                    out_ready,

  output     [AW-1:0]      y
);


  //Stage 0: register inputs

  reg              s0_valid;
  reg [EW-1:0]     s0_a, s0_b;
  reg [AW-1:0]     s0_c;
  reg              s0_mask, s0_signed;

  //Simple 1-deep in-flight control
  wire s1_can_accept = (out_ready | ~out_valid);   //stage1/output can accept new data
  wire s0_can_load   = (~s0_valid) | s1_can_accept;

  assign in_ready = s0_can_load;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      s0_valid  <= 1'b0;
      s0_a      <= {EW{1'b0}};
      s0_b      <= {EW{1'b0}};
      s0_c      <= {AW{1'b0}};
      s0_mask   <= 1'b0;
      s0_signed <= 1'b0;
    end else begin
      if (s0_valid && s1_can_accept)
        s0_valid <= 1'b0;

      if (in_valid && s0_can_load) begin
        s0_valid  <= 1'b1;
        s0_a      <= a;
        s0_b      <= b;
        s0_c      <= c;
        s0_mask   <= lane_mask;
        s0_signed <= op_signed;
      end
    end
  end


  //Stage 1: DSP48 MAC + output reg (single MAC expr → 1 DSP per lane)

  reg              s1_valid;
  reg [AW-1:0]     y_q;

  //Pre-extend operands once (select signed or zero-extend before multiply)
  wire signed [EW:0] a_ext = s0_signed ? $signed({s0_a[EW-1], s0_a})
                                       : $signed({1'b0,       s0_a});
  wire signed [EW:0] b_ext = s0_signed ? $signed({s0_b[EW-1], s0_b})
                                       : $signed({1'b0,       s0_b});

  //C as signed view (bit-identical)
  wire signed [AW-1:0] c_ext = $signed(s0_c);

  //Single A*B + C expression; encourage DSP mapping
  (* use_dsp = "yes" *)
  wire signed [AW-1:0] mac_sum = a_ext * b_ext + c_ext;  //(17x17)->34 then +32 (trunc to 32)

  //Mask after MAC (bypass returns C)
  wire [AW-1:0] y_next = s0_mask ? s0_c : mac_sum;

  //Output regs
  assign out_valid = s1_valid;
  assign y         = y_q;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      s1_valid <= 1'b0;
      y_q      <= {AW{1'b0}};
    end else begin
      if (s1_valid && out_ready)
        s1_valid <= 1'b0;

      if (s0_valid && s1_can_accept) begin
        s1_valid <= 1'b1;
        y_q      <= y_next;   //maps to PREG in DSP
      end
    end
  end

endmodule

