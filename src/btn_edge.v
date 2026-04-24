//============================================================================
// Module: btn_edge
// Description: 2-flop synchronizer + counter-based debouncer + rising-edge
//              detector for mechanical button inputs on the Basys3.
//
// Why a counter debouncer?
//   Mechanical buttons on the Basys3 can bounce for up to ~10 ms after
//   each press or release.  A bare synchronizer + edge detector fires on
//   every bounce transition, causing multiple btn_rise pulses per press.
//   The counter holds off re-triggering for DEBOUNCE_CYCLES clocks after
//   the synchronized signal first changes, absorbing the bounce window.
//
//   DEBOUNCE_CYCLES = 1,000,000 ? 10 ms @ 100 MHz.
//   Change the parameter if you use a different clock frequency.
//============================================================================
module btn_edge #(
    parameter DEBOUNCE_CYCLES = 1_000_000   // 10 ms @ 100 MHz
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output wire btn_rise
);

    // ---------------------------------------------------------------
    // Stage 1: 2-flop synchronizer (metastability guard)
    // ---------------------------------------------------------------
    reg ff1, ff2;
    always @(posedge clk) begin
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= btn_in;
            ff2 <= ff1;
        end
    end

    // ---------------------------------------------------------------
    // Stage 2: counter-based debouncer
    //   db_out tracks the last stable (debounced) level.
    //   Whenever the synchronized input differs from db_out, the
    //   counter starts counting.  Only when the counter reaches
    //   DEBOUNCE_CYCLES does db_out update - confirming the new level
    //   has been held long enough.
    // ---------------------------------------------------------------
    reg [$clog2(DEBOUNCE_CYCLES)-1:0] cnt;
    reg db_out;

    always @(posedge clk) begin
        if (rst) begin
            cnt    <= 0;
            db_out <= 1'b0;
        end else begin
            if (ff2 == db_out) begin
                // Input matches stable level - no change, reset counter
                cnt <= 0;
            end else begin
                if (cnt == DEBOUNCE_CYCLES - 1) begin
                    // Held long enough ? accept new level
                    db_out <= ff2;
                    cnt    <= 0;
                end else begin
                    cnt <= cnt + 1;
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Stage 3: rising-edge detector on the debounced signal
    // ---------------------------------------------------------------
    reg db_prev;
    always @(posedge clk) begin
        if (rst)
            db_prev <= 1'b0;
        else
            db_prev <= db_out;
    end

    assign btn_rise = db_out & ~db_prev;

endmodule