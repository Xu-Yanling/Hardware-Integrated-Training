module counter (
    input  wire       clk,
    input  wire       reset,   // 异步复位
    input  wire       d_inc,    // 需要计数的信号（电平 or 按键）
    input  wire       d_clr,    // 同步清零
    output wire [3:0] dig0,     // 个位 BCD
    output wire [3:0] dig1      // 十位 BCD
);

    // =========================================================
    // 1. 同步 + 上升沿检测
    // =========================================================
    reg d_inc_d;

    always @(posedge clk or posedge reset)
        if (reset)
            d_inc_d <= 1'b0;
        else
            d_inc_d <= d_inc;

    wire d_inc_pulse;
    assign d_inc_pulse = d_inc & ~d_inc_d;   // 只持续 1 个 clk

    // =========================================================
    // 2. BCD 计数寄存器
    // =========================================================
    reg [3:0] dig0_reg, dig1_reg;
    reg [3:0] dig0_next, dig1_next;

    // 寄存器
    always @(posedge clk or posedge reset)
        if (reset) begin
            dig0_reg <= 4'd0;
            dig1_reg <= 4'd0;
        end
        else begin
            dig0_reg <= dig0_next;
            dig1_reg <= dig1_next;
        end

    // =========================================================
    // 3. 下一状态逻辑
    // =========================================================
    always @* begin
        // 默认保持
        dig0_next = dig0_reg;
        dig1_next = dig1_reg;

        if (d_clr) begin
            dig0_next = 4'd0;
            dig1_next = 4'd0;
        end
        else if (d_inc_pulse) begin
            if (dig0_reg == 4'd9) begin
                dig0_next = 4'd0;
                if (dig1_reg == 4'd9)
                    dig1_next = 4'd0;
                else
                    dig1_next = dig1_reg + 4'd1;
            end
            else begin
                dig0_next = dig0_reg + 4'd1;
            end
        end
    end

    // =========================================================
    // 4. 输出
    // =========================================================
    assign dig0 = dig0_reg;
    assign dig1 = dig1_reg;

endmodule

