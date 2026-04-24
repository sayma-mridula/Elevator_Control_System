//============================================================================
// Module: memory_unit
// Description: Stores up to 4 passengers (start floor + destination floor)
//              FIFO write during input phase, random-access read by index
//============================================================================
module memory_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,           // write-enable (one-cycle pulse)
    input  wire [2:0]  w_start,      // start floor to store
    input  wire [2:0]  w_dest,       // destination floor to store
    input  wire [1:0]  r_idx,        // read index (0-3)
    output wire [2:0]  r_start,      // read: start floor
    output wire [2:0]  r_dest,       // read: destination floor
    output wire [2:0]  count,        // passenger count (0-4)
    output wire        full          // memory full flag
);

    // Storage arrays
    reg [2:0] start_mem [0:3];
    reg [2:0] dest_mem  [0:3];
    reg [2:0] passenger_count;       // 0 to 4

    // Combinational read outputs
    assign r_start = start_mem[r_idx];
    assign r_dest  = dest_mem[r_idx];
    assign count   = passenger_count;
    assign full    = (passenger_count == 3'd4);

    // Sequential write logic
    always @(posedge clk) begin
        if (rst) begin
            passenger_count <= 3'd0;
            start_mem[0]    <= 3'd0;
            start_mem[1]    <= 3'd0;
            start_mem[2]    <= 3'd0;
            start_mem[3]    <= 3'd0;
            dest_mem[0]     <= 3'd0;
            dest_mem[1]     <= 3'd0;
            dest_mem[2]     <= 3'd0;
            dest_mem[3]     <= 3'd0;
        end else if (we && !full && (w_start != w_dest)) begin
            // Guard: reject same-floor bookings (fare would be 0, no movement needed)
            start_mem[passenger_count[1:0]] <= w_start;
            dest_mem[passenger_count[1:0]]  <= w_dest;
            passenger_count                 <= passenger_count + 3'd1;
        end
    end

endmodule