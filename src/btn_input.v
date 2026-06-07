`timescale 1ns / 1ps

module btn_input (
    input  wire clk,
    input  wire reset,
    input  wire btnL,
    input  wire btnR,
    input  wire btnU,
    input  wire btnD,
    output reg  [3:0] btn
);

    // ===== 同步 =====
    reg [1:0] l_sync, r_sync, u_sync, d_sync;

    always @(posedge clk) begin
        l_sync <= {l_sync[0], btnL};
        r_sync <= {r_sync[0], btnR};
        u_sync <= {u_sync[0], btnU};
        d_sync <= {d_sync[0], btnD};
    end

    // ===== 消抖计数器 =====
    localparam integer DEBOUNCE_CNT = 20_000; // ~0.4ms @50MHz

    reg [$clog2(DEBOUNCE_CNT)-1:0] cntL, cntR, cntU, cntD;
    reg l_db, r_db, u_db, d_db;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cntL <= 0; cntR <= 0; cntU <= 0; cntD <= 0;
            l_db <= 0; r_db <= 0; u_db <= 0; d_db <= 0;
        end else begin
            // Left
            if (l_sync[1] != l_db) begin
                cntL <= cntL + 1;
                if (cntL == DEBOUNCE_CNT-1) begin
                    l_db <= l_sync[1];
                    cntL <= 0;
                end
            end else cntL <= 0;

            // Right
            if (r_sync[1] != r_db) begin
                cntR <= cntR + 1;
                if (cntR == DEBOUNCE_CNT-1) begin
                    r_db <= r_sync[1];
                    cntR <= 0;
                end
            end else cntR <= 0;

            // Up
            if (u_sync[1] != u_db) begin
                cntU <= cntU + 1;
                if (cntU == DEBOUNCE_CNT-1) begin
                    u_db <= u_sync[1];
                    cntU <= 0;
                end
            end else cntU <= 0;

            // Down
            if (d_sync[1] != d_db) begin
                cntD <= cntD + 1;
                if (cntD == DEBOUNCE_CNT-1) begin
                    d_db <= d_sync[1];
                    cntD <= 0;
                end
            end else cntD <= 0;
        end
    end

    // ===== 上升沿检测（只打一拍） =====
    reg l_prev, r_prev, u_prev, d_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            l_prev <= 0; r_prev <= 0; u_prev <= 0; d_prev <= 0;
            btn <= 4'b0000;
        end else begin
            btn <= 4'b0000; // 默认不动

            if (l_db && !l_prev) btn <= 4'b0001;
            else if (r_db && !r_prev) btn <= 4'b0010;
            else if (u_db && !u_prev) btn <= 4'b0100;
            else if (d_db && !d_prev) btn <= 4'b1000;

            l_prev <= l_db;
            r_prev <= r_db;
            u_prev <= u_db;
            d_prev <= d_db;
        end
    end

endmodule
