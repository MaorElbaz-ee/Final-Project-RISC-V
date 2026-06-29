`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 10:45:29
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top (
    input  logic        clk,   // 100 MHz
    input  logic        reset,   // לחצן reset אם יש
    output logic [6:0]  seg,   // ממופה ל-seg[0]..seg[6] ב-XDC
    output logic        dp,    // dp
    output logic [7:0]  an     // an[0]..an[7]
    );

    logic [31:0] value = 32'h1234_5678;

    seven_Seg_Driver u_disp (
        .clk   (clk),
        .rst   (rst),
        .hex32 (value),
        .seg   (seg),
        .dp    (dp),
        .an    (an)
    );

endmodule
// ======================================================
// 8×7-segment display driver (common-anode, active-LOW)
// Board: Nexys A7 (100 MHz clk)
// seg[0]..seg[6] = a..g (active-LOW), dp active-LOW
// an[0]..an[7] = digit enables (active-LOW)
// ======================================================
module seven_Seg_Driver (
    input  logic        clk,     // 100 MHz
    input  logic        rst,     // async or sync (משמש כאן כסינכרוני)
    input  logic [31:0] hex32,   // 8 ניבלים להצגה: [31:28] ... [3:0]

    output logic [6:0]  seg,     // a..g (active-LOW)
    output logic        dp,      // decimal point (active-LOW)
    output logic [7:0]  an       // digit enables (active-LOW)
);

    // --------------------------------------------------
    // מחלק שעון: נשתמש בביטים [16:14] לבחירת ספרה
    // 100 MHz / 2^(14) ≈ 6103 Hz "טיקט ספרה"  ⇒ ~763 Hz לכל ספרה (8 ספרות)
    // --------------------------------------------------
    logic [23:0] cnt;
    always_ff @(posedge clk) begin
        if (rst) cnt <= '0;
        else     cnt <= cnt + 24'd1;
    end

    logic [2:0] digit_sel;
    assign digit_sel = cnt[16:14];

    // --------------------------------------------------
    // בחירת הניבל המתאים לפי הספרה הפעילה
    // --------------------------------------------------
    logic [3:0] nibble;
    always_comb begin
        unique case (digit_sel)
            3'd0: nibble = hex32[ 3: 0];
            3'd1: nibble = hex32[ 7: 4];
            3'd2: nibble = hex32[11: 8];
            3'd3: nibble = hex32[15:12];
            3'd4: nibble = hex32[19:16];
            3'd5: nibble = hex32[23:20];
            3'd6: nibble = hex32[27:24];
            default: nibble = hex32[31:28];
        endcase
    end

    // --------------------------------------------------
    // מקודד HEX -> 7-SEG (a..g), אקטיבי-נמוך
    //              g f e d c b a  (לנוחות מוצג כשמאל→ימין)
    // seg = {a..g} לפי המיפוי שלך: seg[0]=a, ... seg[6]=g
    // כאן נחזיר בפועל וקטור a..g בסדר seg[6:0] = {g,f,e,d,c,b,a}
    // --------------------------------------------------
    function automatic logic [6:0] hex_to_7seg_n (input logic [3:0] h);
        // "דלוק" = 0, "כבוי" = 1
        // תבניות מסונכרנות לגרסאות אקטיביות-נמוכות
        unique case (h)
             4'h0: hex_to_7seg_n = 7'b1000000; // 0
             4'h1: hex_to_7seg_n = 7'b1111001; // 1
             4'h2: hex_to_7seg_n = 7'b0100100; // 2
             4'h3: hex_to_7seg_n = 7'b0110000; // 3
             4'h4: hex_to_7seg_n = 7'b0011001; // 4
             4'h5: hex_to_7seg_n = 7'b0010010; // 5
             4'h6: hex_to_7seg_n = 7'b0000010; // 6
             4'h7: hex_to_7seg_n = 7'b1111000; // 7
             4'h8: hex_to_7seg_n = 7'b0000000; // 8
             4'h9: hex_to_7seg_n = 7'b0010000; // 9
             4'hA: hex_to_7seg_n = 7'b0001000; // A
             4'hB: hex_to_7seg_n = 7'b0000011; // b
             4'hC: hex_to_7seg_n = 7'b1000110; // C
             4'hD: hex_to_7seg_n = 7'b0100001; // d
             4'hE: hex_to_7seg_n = 7'b0000110; // E
             default: hex_to_7seg_n = 7'b0001110; // F
        endcase
    endfunction

    // פלטי הסגמנטים (a..g) אקטיבי-נמוך
    always_comb begin
        seg = hex_to_7seg_n(nibble);
    end

    // נקודה עשרונית כבויה כברירת מחדל (אקטיבי-נמוך)
    // אם תרצה להדליק נקודה בספרה מסוימת, החלף לפי digit_sel
    always_comb begin
        dp = 1'b1;
        // דוגמה: להדליק dp רק בספרה 3
        // dp = (digit_sel == 3'd3) ? 1'b0 : 1'b1;
    end

    // --------------------------------------------------
    // אנודות (active-LOW): מפעילים ספרה אחת בכל רגע
    // --------------------------------------------------
    always_comb begin
        unique case (digit_sel)
            3'd0: an = 8'b1111_1110; // ספרה 0 פעילה
            3'd1: an = 8'b1111_1101;
            3'd2: an = 8'b1111_1011;
            3'd3: an = 8'b1111_0111;
            3'd4: an = 8'b1110_1111;
            3'd5: an = 8'b1101_1111;
            3'd6: an = 8'b1011_1111;
            default: an = 8'b0111_1111; // ספרה 7 פעילה
        endcase
    end

endmodule
