//============================================================================
// Module: alu
// Description: Combinational fare calculator
//              fare = 5 * |destination - start|
//              Output range: 0, 5, 10, 15, 20, 25, 30, 35
//============================================================================
module alu (
    input  wire [2:0] start_floor,
    input  wire [2:0] dest_floor,
    output wire [5:0] fare
);

    // Step 1: absolute difference |dest - start|  (range 0-7)
    wire [2:0] abs_diff = (dest_floor >= start_floor)
                          ? (dest_floor - start_floor)
                          : (start_floor - dest_floor);

    // Step 2: extend to 6 bits for safe arithmetic
    wire [5:0] diff6 = {3'b000, abs_diff};

    // Step 3: fare = 5 * abs_diff = (4 * abs_diff) + abs_diff
    //   diff6 << 2 = 4*diff,  + diff6 = 5*diff
    assign fare = (diff6 << 2) + diff6;

endmodule
