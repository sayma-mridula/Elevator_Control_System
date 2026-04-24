//============================================================================
// Module: seven_segment
// Description: Multiplexed 7-segment display driver (AN0 & AN1 only)
//              Displays two digits based on mode:
//                mode 0 → "00"  (IDLE)
//                mode 1 → "0F"  (F = floor, during movement)
//                mode 2 → fare in taka (pre-computed by ALU: 05,10,...,35)
//                mode 3 → "EE"  (DONE)
//              AN2 and AN3 are always OFF
//============================================================================
module seven_segment (
    input  wire        clk,
    input  wire        rst,
    input  wire        seg_tick,       // ~1 kHz refresh pulse
    input  wire [1:0]  disp_mode,      // display mode (0-3)
    input  wire [5:0]  disp_value,     // value to show (floor 0-7 or fare 0-35)
    output reg  [6:0]  seg,            // cathode outputs (active-low, a-g)
    output reg  [3:0]  an              // anode outputs   (active-low)
);

    // Toggle between digit 0 (AN0) and digit 1 (AN1)
    reg toggle;

    always @(posedge clk) begin
        if (rst)
            toggle <= 1'b0;
        else if (seg_tick)
            toggle <= ~toggle;
    end

    //------------------------------------------------------------------
    // Fare digit extraction (fare already = 5 * floors, from ALU)
    //   Split into tens and units for display.
    //   Valid fare values: 0, 5, 10, 15, 20, 25, 30, 35
    //------------------------------------------------------------------
    reg [3:0] fare_tens;
    reg [3:0] fare_units;

    always @(*) begin
        case (disp_value)
            6'd0:    begin fare_tens = 4'd0; fare_units = 4'd0; end
            6'd5:    begin fare_tens = 4'd0; fare_units = 4'd5; end
            6'd10:   begin fare_tens = 4'd1; fare_units = 4'd0; end
            6'd15:   begin fare_tens = 4'd1; fare_units = 4'd5; end
            6'd20:   begin fare_tens = 4'd2; fare_units = 4'd0; end
            6'd25:   begin fare_tens = 4'd2; fare_units = 4'd5; end
            6'd30:   begin fare_tens = 4'd3; fare_units = 4'd0; end
            6'd35:   begin fare_tens = 4'd3; fare_units = 4'd5; end
            default: begin fare_tens = 4'd0; fare_units = 4'd0; end
        endcase
    end

    // Determine the 4-bit digit to display on the active anode
    reg [3:0] current_digit;

    always @(*) begin
        // Defaults — all anodes OFF, all segments OFF, digit = 0
        an            = 4'b1111;
        current_digit = 4'd0;

        if (toggle) begin
            // ---- AN1 (left / tens digit) ----
            an = 4'b1101;
            case (disp_mode)
                2'd0:    current_digit = 4'd0;        // "0_"
                2'd1:    current_digit = 4'd0;        // "0F"
                2'd2:    current_digit = fare_tens;   // fare tens (0-3)
                2'd3:    current_digit = 4'd14;       // "E_"
                default: current_digit = 4'd0;
            endcase
        end else begin
            // ---- AN0 (right / units digit) ----
            an = 4'b1110;
            case (disp_mode)
                2'd0:    current_digit = 4'd0;                      // "_0"
                2'd1:    current_digit = disp_value[3:0];           // floor
                2'd2:    current_digit = fare_units;                // fare units (0 or 5)
                2'd3:    current_digit = 4'd14;                     // "_E"
                default: current_digit = 4'd0;
            endcase
        end

        // Decode digit → 7-segment pattern (active-low: 0 = segment ON)
        // Segment order: seg[6]=a, seg[5]=b, ..., seg[0]=g
        case (current_digit)
            4'd0:    seg = 7'b0000001;  // 0
            4'd1:    seg = 7'b1001111;  // 1
            4'd2:    seg = 7'b0010010;  // 2
            4'd3:    seg = 7'b0000110;  // 3
            4'd4:    seg = 7'b1001100;  // 4
            4'd5:    seg = 7'b0100100;  // 5
            4'd6:    seg = 7'b0100000;  // 6
            4'd7:    seg = 7'b0001111;  // 7
            4'd8:    seg = 7'b0000000;  // 8
            4'd9:    seg = 7'b0000100;  // 9
            4'd14:   seg = 7'b0110000;  // E
            default: seg = 7'b1111111;  // blank
        endcase
    end

endmodule
