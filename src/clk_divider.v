//============================================================================
// Module: clk_divider
// Description: Generates enable pulses from 100MHz clock
//              slow_tick ~ 2 Hz  (for floor-by-floor movement)
//              seg_tick  ~ 1 kHz (for 7-segment multiplexing)
//============================================================================
module clk_divider (
    input  wire clk,
    input  wire rst,
    output reg  slow_tick,
    output reg  seg_tick
);

    //----------------------------------------------------------------------
    // Slow tick: 100 MHz / 50,000,000 = 2 Hz
    //----------------------------------------------------------------------
    reg [25:0] slow_cnt;

    always @(posedge clk) begin
        if (rst) begin
            slow_cnt  <= 26'd0;
            slow_tick <= 1'b0;
        end else begin
            if (slow_cnt == 26'd49_999_999) begin
                slow_cnt  <= 26'd0;
                slow_tick <= 1'b1;
            end else begin
                slow_cnt  <= slow_cnt + 26'd1;
                slow_tick <= 1'b0;
            end
        end
    end

    //----------------------------------------------------------------------
    // Segment tick: 100 MHz / 100,000 = 1 kHz
    //----------------------------------------------------------------------
    reg [16:0] seg_cnt;

    always @(posedge clk) begin
        if (rst) begin
            seg_cnt  <= 17'd0;
            seg_tick <= 1'b0;
        end else begin
            if (seg_cnt == 17'd99_999) begin
                seg_cnt  <= 17'd0;
                seg_tick <= 1'b1;
            end else begin
                seg_cnt  <= seg_cnt + 17'd1;
                seg_tick <= 1'b0;
            end
        end
    end

endmodule
