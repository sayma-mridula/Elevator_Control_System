//============================================================================
// Module: control_unit
// Description: Main FSM for elevator control - sweep-based multi-passenger
//   The elevator picks up ALL passengers at their start floors and drops
//   them off at their destinations during a single directional sweep.
//
//   States: IDLE ? LATCH ? CALC_DIR ? MOVE_TO_FIRST ? CHECK_FLOOR ?
//           ARRIVE_PAUSE ? WAIT_PAYMENT ? MOVE_NEXT ? DONE
//============================================================================
module control_unit (
    input  wire        clk,
    input  wire        rst,
    // Button edges
    input  wire        btn_add,          // btnC: add passenger
    input  wire        btn_start,        // btnU: start processing
    input  wire        btn_pay,          // btnD: confirm payment
    // Timing
    input  wire        slow_tick,        // ~2 Hz movement tick
    // ALU
    input  wire [5:0]  fare,            // from ALU: 5 * |dest - start|
    // Payment
    input  wire [5:0]  payment,         // SW[15:10]
    // Memory interface
    input  wire [2:0]  passenger_count, // from memory_unit
    input  wire        mem_full,        // from memory_unit
    input  wire [2:0]  mem_start,       // memory read: start floor
    input  wire [2:0]  mem_dest,        // memory read: dest floor
    // Outputs
    output reg  [2:0]  current_floor,
    output reg  [1:0]  current_idx,     // read index for memory
    output reg         mem_we,          // write enable for memory
    output reg         led_up,          // LED0: moving up
    output reg         led_down,        // LED1: moving down
    output reg         led_full,        // LED15: memory full
    output reg  [1:0]  disp_mode,       // display mode for seven_segment
    output reg  [5:0]  disp_value       // display value for seven_segment
);

    //------------------------------------------------------------------
    // State encoding (4-bit for 9 states)
    //------------------------------------------------------------------
    parameter S_IDLE          = 4'd0;
    parameter S_LATCH         = 4'd1;  // read passengers from memory
    parameter S_CALC_DIR      = 4'd2;  // determine sweep direction
    parameter S_MOVE_TO_FIRST = 4'd3;  // move to first start floor
    parameter S_CHECK_FLOOR   = 4'd4;  // check pickup / dropoff
    parameter S_ARRIVE_PAUSE  = 4'd5;  // pause at floor before fare
    parameter S_WAIT_PAYMENT  = 4'd6;  // show fare, wait payment
    parameter S_MOVE_NEXT     = 4'd7;  // advance one floor
    parameter S_DONE          = 4'd8;  // all passengers served

    reg [3:0] state;

    //------------------------------------------------------------------
    // Latched passenger data (local copies from memory)
    //------------------------------------------------------------------
    reg [2:0] p_start [0:3];
    reg [2:0] p_dest  [0:3];

    //------------------------------------------------------------------
    // Tracking registers
    //------------------------------------------------------------------
    reg [3:0] picked_up;           // bitmask: passenger i picked up
    reg [3:0] delivered;           // bitmask: passenger i delivered & paid
    reg       sweep_up;            // 1 = sweeping upward, 0 = downward
    reg [1:0] latch_idx;           // index during memory latching
    reg [1:0] active_idx;          // passenger currently exiting (for fare)
    reg [2:0] first_floor;         // sweep starting floor
    reg [2:0] pause_cnt;           // pause counter at destination
    reg       processing;          // set after btnU, prevents more adds
    reg [2:0] pass_count_latched;  // latched passenger count

    //------------------------------------------------------------------
    // Combinational: pickup detection at current floor
    //   Which passengers have start == current_floor and haven't
    //   been picked up yet?
    //------------------------------------------------------------------
    wire [3:0] pickup_now;
    assign pickup_now[0] = (p_start[0] == current_floor) && !picked_up[0] && (pass_count_latched > 3'd0);
    assign pickup_now[1] = (p_start[1] == current_floor) && !picked_up[1] && (pass_count_latched > 3'd1);
    assign pickup_now[2] = (p_start[2] == current_floor) && !picked_up[2] && (pass_count_latched > 3'd2);
    assign pickup_now[3] = (p_start[3] == current_floor) && !picked_up[3] && (pass_count_latched > 3'd3);

    //------------------------------------------------------------------
    // Combinational: dropoff detection at current floor
    //   Which passengers have dest == current_floor, are picked up,
    //   and haven't been delivered yet?
    //------------------------------------------------------------------
    wire [3:0] dropoff_now;
    assign dropoff_now[0] = (p_dest[0] == current_floor) && picked_up[0] && !delivered[0] && (pass_count_latched > 3'd0);
    assign dropoff_now[1] = (p_dest[1] == current_floor) && picked_up[1] && !delivered[1] && (pass_count_latched > 3'd1);
    assign dropoff_now[2] = (p_dest[2] == current_floor) && picked_up[2] && !delivered[2] && (pass_count_latched > 3'd2);
    assign dropoff_now[3] = (p_dest[3] == current_floor) && picked_up[3] && !delivered[3] && (pass_count_latched > 3'd3);

    wire has_dropoff = |dropoff_now;

    // Priority encoder: lowest-index passenger exits first
    wire [1:0] drop_idx = dropoff_now[0] ? 2'd0 :
                          dropoff_now[1] ? 2'd1 :
                          dropoff_now[2] ? 2'd2 : 2'd3;

    //------------------------------------------------------------------
    // Combinational: all passengers delivered?
    //------------------------------------------------------------------
    wire [3:0] expected_mask = (pass_count_latched == 3'd1) ? 4'b0001 :
                               (pass_count_latched == 3'd2) ? 4'b0011 :
                               (pass_count_latched == 3'd3) ? 4'b0111 :
                               (pass_count_latched == 3'd4) ? 4'b1111 : 4'b0000;

    wire all_delivered = ((delivered & expected_mask) == expected_mask) && (pass_count_latched > 3'd0);

    //------------------------------------------------------------------
    // Combinational: predict if all will be delivered after current payment
    //   Used in S_WAIT_PAYMENT to decide: continue sweep or show EE
    //------------------------------------------------------------------
    wire [3:0] delivered_after_pay = delivered | (4'b0001 << active_idx);
    wire all_done_after_pay = ((delivered_after_pay & expected_mask) == expected_mask)
                              && (pass_count_latched > 3'd0);

    //------------------------------------------------------------------
    // Combinational: minimum start floor (sweep-up origin)
    //   Invalid passenger slots use 7 so they don't affect min
    //------------------------------------------------------------------
    wire [2:0] su0 = p_start[0];
    wire [2:0] su1 = (pass_count_latched > 3'd1) ? p_start[1] : 3'd7;
    wire [2:0] su2 = (pass_count_latched > 3'd2) ? p_start[2] : 3'd7;
    wire [2:0] su3 = (pass_count_latched > 3'd3) ? p_start[3] : 3'd7;
    wire [2:0] min_s01 = (su0 <= su1) ? su0 : su1;
    wire [2:0] min_s23 = (su2 <= su3) ? su2 : su3;
    wire [2:0] min_start_floor = (min_s01 <= min_s23) ? min_s01 : min_s23;

    //------------------------------------------------------------------
    // Combinational: maximum start floor (sweep-down origin)
    //   Invalid passenger slots use 0 so they don't affect max
    //------------------------------------------------------------------
    wire [2:0] sd0 = p_start[0];
    wire [2:0] sd1 = (pass_count_latched > 3'd1) ? p_start[1] : 3'd0;
    wire [2:0] sd2 = (pass_count_latched > 3'd2) ? p_start[2] : 3'd0;
    wire [2:0] sd3 = (pass_count_latched > 3'd3) ? p_start[3] : 3'd0;
    wire [2:0] max_s01 = (sd0 >= sd1) ? sd0 : sd1;
    wire [2:0] max_s23 = (sd2 >= sd3) ? sd2 : sd3;
    wire [2:0] max_start_floor = (max_s01 >= max_s23) ? max_s01 : max_s23;

    //------------------------------------------------------------------
    // Main FSM
    //------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state              <= S_IDLE;
            current_floor      <= 3'd0;
            current_idx        <= 2'd0;
            mem_we             <= 1'b0;
            led_up             <= 1'b0;
            led_down           <= 1'b0;
            led_full           <= 1'b0;
            disp_mode          <= 2'd0;
            disp_value         <= 6'd0;
            picked_up          <= 4'b0000;
            delivered          <= 4'b0000;
            sweep_up           <= 1'b1;
            latch_idx          <= 2'd0;
            active_idx         <= 2'd0;
            first_floor        <= 3'd0;
            pause_cnt          <= 3'd0;
            processing         <= 1'b0;
            pass_count_latched <= 3'd0;
            p_start[0] <= 3'd0; p_start[1] <= 3'd0;
            p_start[2] <= 3'd0; p_start[3] <= 3'd0;
            p_dest[0]  <= 3'd0; p_dest[1]  <= 3'd0;
            p_dest[2]  <= 3'd0; p_dest[3]  <= 3'd0;
        end else begin
            //----------------------------------------------------------
            // Defaults (overridden in specific states as needed)
            //----------------------------------------------------------
            mem_we   <= 1'b0;
            led_up   <= 1'b0;
            led_down <= 1'b0;
            led_full <= mem_full;

            case (state)
                //======================================================
                // IDLE: accept passengers via btnC, start via btnU
                //======================================================
                S_IDLE: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, passenger_count};

                    if (btn_start && passenger_count > 3'd0) begin
                        processing         <= 1'b1;
                        latch_idx          <= 2'd0;
                        current_idx        <= 2'd0;  // prepare memory read
                        pass_count_latched <= passenger_count;
                        picked_up          <= 4'b0000;
                        delivered          <= 4'b0000;
                        state              <= S_LATCH;
                    end
                    else if (!processing && btn_add && !mem_full) begin
                        mem_we <= 1'b1;
                    end
                end

                //======================================================
                // LATCH: read all passenger data from memory into
                //        local registers (one passenger per cycle)
                //======================================================
                S_LATCH: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, passenger_count};

                    // current_idx was set in previous cycle ? read is valid
                    p_start[latch_idx] <= mem_start;
                    p_dest[latch_idx]  <= mem_dest;

                    if ({1'b0, latch_idx} + 3'd1 >= pass_count_latched) begin
                        // All passengers latched
                        state <= S_CALC_DIR;
                    end else begin
                        latch_idx   <= latch_idx + 2'd1;
                        current_idx <= latch_idx + 2'd1;
                    end
                end

                //======================================================
                // CALC_DIR: determine sweep direction and first floor
                //   Direction from first passenger: dest >= start ? up
                //   First floor: min start (up) or max start (down)
                //======================================================
                S_CALC_DIR: begin
                    disp_mode  <= 2'd1;
                    disp_value <= 6'd0;

                    if (p_dest[0] >= p_start[0]) begin
                        sweep_up    <= 1'b1;
                        first_floor <= min_start_floor;
                    end else begin
                        sweep_up    <= 1'b0;
                        first_floor <= max_start_floor;
                    end

                    state <= S_MOVE_TO_FIRST;
                end

                //======================================================
                // MOVE_TO_FIRST: move elevator to the first start floor
                //   Display shows the target floor (static, hides
                //   the internal movement from the user)
                //======================================================
                S_MOVE_TO_FIRST: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, first_floor};

                    if (current_floor == first_floor) begin
                        // Arrived - pick up passengers here
                        picked_up <= picked_up | pickup_now;
                        state     <= S_CHECK_FLOOR;
                    end else begin
                        if (current_floor < first_floor)
                            led_up <= 1'b1;
                        else
                            led_down <= 1'b1;

                        if (slow_tick) begin
                            if (current_floor < first_floor)
                                current_floor <= current_floor + 3'd1;
                            else
                                current_floor <= current_floor - 3'd1;
                        end
                    end
                end

                //======================================================
                // CHECK_FLOOR: at the current floor, auto-pickup
                //   passengers and check if anyone needs to exit
                //======================================================
                S_CHECK_FLOOR: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, current_floor};

                    // Auto-pickup any passengers starting at this floor
                    picked_up <= picked_up | pickup_now;

                    if (all_delivered) begin
                        // Everyone has been served
                        state <= S_DONE;
                    end else if (has_dropoff) begin
                        // A passenger exits here - prepare fare display
                        active_idx  <= drop_idx;
                        current_idx <= drop_idx;  // ALU reads next cycle
                        pause_cnt   <= 3'd0;
                        state       <= S_ARRIVE_PAUSE;
                    end else begin
                        // Nobody exits here - keep moving
                        state <= S_MOVE_NEXT;
                    end
                end

                //======================================================
                // ARRIVE_PAUSE: stay at the floor for ~2 s showing
                //   the floor number before switching to fare display
                //======================================================
                S_ARRIVE_PAUSE: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, current_floor};

                    if (pause_cnt >= 3'd4) begin
                        pause_cnt <= 3'd0;
                        state     <= S_WAIT_PAYMENT;
                    end else if (slow_tick) begin
                        pause_cnt <= pause_cnt + 3'd1;
                    end
                end

                //======================================================
                // WAIT_PAYMENT: display fare, wait for payment
                //   current_idx was set to active_idx in CHECK_FLOOR,
                //   so the ALU output (fare) is valid here.
                //======================================================
                S_WAIT_PAYMENT: begin
                    disp_mode  <= 2'd2;
                    disp_value <= fare;    // ALU gives 5 * |dest - start|

                    if (btn_pay) begin
                        if (payment >= fare) begin
                            // Mark passenger as delivered
                            delivered <= delivered | (4'b0001 << active_idx);

                            if (all_done_after_pay) begin
                                // Last passenger - show EE
                                state <= S_DONE;
                            end else begin
                                // More passengers to serve - continue sweep
                                state <= S_CHECK_FLOOR;
                            end
                        end
                        // else: stay - insufficient payment
                    end
                end

                //======================================================
                // MOVE_NEXT: advance one floor in sweep direction
                //   Reverses direction if boundary (floor 0 or 7) hit
                //======================================================
                S_MOVE_NEXT: begin
                    disp_mode  <= 2'd1;
                    disp_value <= {3'd0, current_floor};

                    if (sweep_up)
                        led_up <= 1'b1;
                    else
                        led_down <= 1'b1;

                    if (slow_tick) begin
                        if (sweep_up && current_floor < 3'd7)
                            current_floor <= current_floor + 3'd1;
                        else if (!sweep_up && current_floor > 3'd0)
                            current_floor <= current_floor - 3'd1;
                        else
                            sweep_up <= ~sweep_up;  // reverse at boundary

                        state <= S_CHECK_FLOOR;
                    end
                end

                //======================================================
                // DONE: all passengers processed - show "EE"
                //   Press btnU to return to IDLE for a new batch
                //======================================================
                S_DONE: begin
                    disp_mode  <= 2'd3;
                    disp_value <= 6'd0;

                    if (btn_start) begin
                        processing <= 1'b0;
                        state      <= S_IDLE;
                    end
                end

                //======================================================
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule