`timescale 1ns/1ps

module top_fpga (
  input  wire clk_in,     // board clock (e.g., 100 MHz)
  input  wire rst_btn,    // active-high reset button/signal
  output wire led_pass,
  output wire led_busy,
  output wire led_error
);


//Reset sync (2-flop)

  reg [1:0] rst_sync = 2'b11;
  always @(posedge clk_in) begin
    rst_sync <= {rst_sync[0], rst_btn};
  end
  wire rst = rst_sync[1];

//DUT Interface

  reg         in_valid   = 1'b0;
  wire        in_ready;
  wire        out_valid;
  reg         out_ready  = 1'b1;

  reg  [63:0]  a_vec     = 64'd0;
  reg  [63:0]  b_vec     = 64'd0;
  reg [127:0]  c_vec     = 128'd0;
  reg  [3:0]   lane_mask = 4'b0000;
  reg          op_signed = 1'b0;
  wire [127:0] y_vec;


//Instantiate MAC

  mac4x16_top dut (
    .clk(clk_in), .rst(rst),
    .in_valid(in_valid), .in_ready(in_ready),
    .out_valid(out_valid), .out_ready(out_ready),
    .a_vec(a_vec), .b_vec(b_vec), .c_vec(c_vec),
    .lane_mask(lane_mask), .op_signed(op_signed),
    .y_vec(y_vec)
  );


//FSM to drive a single directed test
//Test = Unsigned, C=0: a=[1,2,3,4] b=[5,6,7,8] => y=[5,12,21,32]

  localparam S_IDLE = 3'd0,
             S_LOAD = 3'd1,
             S_WAIT_INREADY = 3'd2,
             S_DROP_VALID = 3'd3,
             S_WAIT_OUT = 3'd4,
             S_CHECK = 3'd5,
             S_DONE = 3'd6,
             S_FAIL = 3'd7;

  reg [2:0] state = S_IDLE;

  //expected packed result {y3,y2,y1,y0}
  wire [127:0] y_exp = {32'd32, 32'd21, 32'd12, 32'd5};

  //LEDs (registered)
  reg led_pass_r = 1'b0, led_busy_r = 1'b0, led_error_r = 1'b0;
  assign led_pass  = led_pass_r;
  assign led_busy  = led_busy_r;
  assign led_error = led_error_r;

  always @(posedge clk_in) begin
    if (rst) begin
      state       <= S_IDLE;
      in_valid    <= 1'b0;
      op_signed   <= 1'b0;
      lane_mask   <= 4'b0000;
      a_vec       <= 64'd0;
      b_vec       <= 64'd0;
      c_vec       <= 128'd0;
      led_pass_r  <= 1'b0;
      led_busy_r  <= 1'b0;
      led_error_r <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          led_busy_r <= 1'b1;
          //program the test vectors
          a_vec     <= {16'd4,16'd3,16'd2,16'd1};
          b_vec     <= {16'd8,16'd7,16'd6,16'd5};
          c_vec     <= 128'd0;
          op_signed <= 1'b0;
          lane_mask <= 4'b0000;
          in_valid  <= 1'b1;
          state     <= S_WAIT_INREADY;
        end

        S_WAIT_INREADY: begin
          if (in_ready) state <= S_DROP_VALID;
        end

        S_DROP_VALID: begin
          in_valid <= 1'b0;     //send one beat
          state    <= S_WAIT_OUT;
        end

        S_WAIT_OUT: begin
          if (out_valid) state <= S_CHECK;
        end

        S_CHECK: begin
          if (y_vec == y_exp) begin
            led_pass_r  <= 1'b1;
            led_busy_r  <= 1'b0;
            state       <= S_DONE;
          end else begin
            led_error_r <= 1'b1;
            led_busy_r  <= 1'b0;
            state       <= S_FAIL;
          end
        end

        S_DONE: begin
          //latch PASS; sit here
        end

        S_FAIL: begin
          //latch ERROR; sit here
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
