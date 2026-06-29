module flip_seg(
    input  logic clk,         // 100 MHz
    input  logic reset_n,     // from C12, ACTIVE-LOW
    output logic [6:0] seg,   // active-LOW
    output logic [7:0] an     // active-LOW
);

    // make an internal ACTIVE-HIGH, synchronous reset
    logic rst1, rst2, reset;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rst1 <= 1'b1;
            rst2 <= 1'b1;
        end else begin
            rst1 <= 1'b0;
            rst2 <= rst1;
        end
    end
    assign reset = rst2;  // active-HIGH inside the design

    // 0.67 s divider
    logic [25:0] cnt;
    always_ff @(posedge clk or posedge reset)
        if (reset) cnt <= 26'd0;
        else       cnt <= cnt + 1'b1;

    // toggle every wrap
    logic flip;
    always_ff @(posedge clk or posedge reset)
        if (reset)          flip <= 1'b0;
        else if (cnt == 0)  flip <= ~flip;

    // display
    always_comb seg = flip ? 7'b0111111  // '-' (active-LOW)
                           : 7'b1000000; // '0'
    assign an = 8'b1111_1110;            // enable rightmost digit only
endmodule
