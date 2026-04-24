//============================================================================
// Module: elevator_top
// Description: Top-level module for Basys3 Elevator Control System
//              Instantiates and wires all sub-modules
//============================================================================
module elevator_top (
    input  wire        clk,        // 100 MHz system clock (W5)
    input  wire [15:0] sw,         // slide switches
    input  wire        btnC,       // center button: add passenger
    input  wire        btnU,       // up button:     start processing
    input  wire        btnD,       // down button:   confirm payment
    input  wire        btnR,       // right button:  reset (active HIGH)
    output wire        LED0,       // moving UP indicator
    output wire        LED1,       // moving DOWN indicator
    output wire        LED15,      // memory FULL indicator
    output wire [6:0]  seg,        // 7-segment cathodes (active-low)
    output wire        dp,         // 7-segment decimal point (active-low)
    output wire [3:0]  an          // 7-segment anodes (active-low)
);

    //==================================================================
    // Reset synchronizer (2-flop, level-sensitive)
    //==================================================================
    reg rst_ff1, rst_ff2;
    always @(posedge clk) begin
        rst_ff1 <= btnR;
        rst_ff2 <= rst_ff1;
    end
    wire rst = rst_ff2;

    //==================================================================
    // Decimal point OFF
    //==================================================================
    assign dp = 1'b1;

    //==================================================================
    // Button edge detectors
    //==================================================================
    wire btnC_edge, btnU_edge, btnD_edge;

    btn_edge u_btn_add (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (btnC),
        .btn_rise(btnC_edge)
    );

    btn_edge u_btn_start (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (btnU),
        .btn_rise(btnU_edge)
    );

    btn_edge u_btn_pay (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (btnD),
        .btn_rise(btnD_edge)
    );

    //==================================================================
    // Clock divider
    //==================================================================
    wire slow_tick, seg_tick;

    clk_divider u_clk_div (
        .clk       (clk),
        .rst       (rst),
        .slow_tick (slow_tick),
        .seg_tick  (seg_tick)
    );

    //==================================================================
    // Memory unit
    //==================================================================
    wire [1:0] current_idx;
    wire       mem_we;
    wire [2:0] mem_start, mem_dest;
    wire [2:0] passenger_count;
    wire       mem_full;

    memory_unit u_memory (
        .clk     (clk),
        .rst     (rst),
        .we      (mem_we),
        .w_start (sw[5:3]),         // start floor from switches
        .w_dest  (sw[2:0]),         // dest  floor from switches
        .r_idx   (current_idx),
        .r_start (mem_start),
        .r_dest  (mem_dest),
        .count   (passenger_count),
        .full    (mem_full)
    );

    //==================================================================
    // ALU (fare calculator)
    //==================================================================
    wire [5:0] fare;

    alu u_alu (
        .start_floor (mem_start),
        .dest_floor  (mem_dest),
        .fare        (fare)
    );

    //==================================================================
    // Control unit (FSM)
    //==================================================================
    wire [2:0] current_floor;
    wire       led_up, led_down, led_full;
    wire [1:0] disp_mode;
    wire [5:0] disp_value;

    control_unit u_fsm (
        .clk             (clk),
        .rst             (rst),
        .btn_add         (btnC_edge),
        .btn_start       (btnU_edge),
        .btn_pay         (btnD_edge),
        .slow_tick       (slow_tick),
        .fare            (fare),
        .payment         (sw[15:10]),
        .passenger_count (passenger_count),
        .mem_full        (mem_full),
        .mem_start       (mem_start),
        .mem_dest        (mem_dest),
        .current_floor   (current_floor),
        .current_idx     (current_idx),
        .mem_we          (mem_we),
        .led_up          (led_up),
        .led_down        (led_down),
        .led_full        (led_full),
        .disp_mode       (disp_mode),
        .disp_value      (disp_value)
    );

    //==================================================================
    // LED assignments
    //==================================================================
    assign LED0  = led_up;
    assign LED1  = led_down;
    assign LED15 = led_full;

    //==================================================================
    // 7-segment display
    //==================================================================
    seven_segment u_display (
        .clk        (clk),
        .rst        (rst),
        .seg_tick   (seg_tick),
        .disp_mode  (disp_mode),
        .disp_value (disp_value),
        .seg        (seg),
        .an         (an)
    );

endmodule
