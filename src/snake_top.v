`timescale 1ns / 1ps

module test2 (
    input  wire clk,
    input  wire reset,
    input  wire d_clr,
    input  wire start,

    // Nexys4 buttons
    input  wire btnL,
    input  wire btnR,
    input  wire btnU,
    input  wire btnD,

    output wire hsync,
    output wire vsync,
    output wire [11:0] rgb,
    output wire [3:0] led1,
    output wire [3:0] led2
);

    // ===== 信号声明 =====
    wire [9:0] pixel_x, pixel_y;
    wire video_on, pixel_tick;
    reg  [11:0] rgb_reg;
    wire [11:0] rgb_next;
    wire clk_50m;

    wire [3:0] btn;
    wire [3:0] dig0, dig1;
    reg d_inc;

    wire goodCollision, badCollision;
    reg  newApple;
    assign led1=dig0;
    assign led2=dig1;
    // ===== 时钟 =====
    clk_50m_generator myclk (
        .clk(clk),
        .reset_clk(reset),
        .clk_50m(clk_50m)
    );

    // ===== 按钮输入 =====
    btn_input btn_unit (
        .clk(clk_50m),
        .reset(reset),
        .btnL(btnL),
        .btnR(btnR),
        .btnU(btnU),
        .btnD(btnD),
        .btn(btn)
    );

    // ===== VGA =====
    vga_sync vsync_unit (
        .clk(clk_50m),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .p_tick(pixel_tick),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    // ===== 图形 =====
    snake_graph snake_graph_unit (
        .clk(clk_50m),
        .reset(reset),
        .start(start),
        .btn(btn),
        .video_on(video_on),
        .pix_x(pixel_x),
        .pix_y(pixel_y),
        .dig0(dig0),
        .dig1(dig1),
        .graph_rgb(rgb_next),
        .goodCollision(goodCollision),
        .badCollision(badCollision),
        .newApple(newApple)
    );

    // ===== 计分 =====
    counter counter_unit (
        .clk(clk_50m),
        .reset(reset),
        .d_inc(d_inc),
        .d_clr(d_clr),
        .dig0(dig0),
        .dig1(dig1)
    );

    // ===== 游戏逻辑 =====
    always @(posedge clk_50m or posedge reset) begin
        if (reset) begin
            d_inc    <= 1'b0;
            newApple <= 1'b1;
        end else begin
            d_inc    <= goodCollision;
            newApple <= goodCollision;
        end
    end

    // ===== RGB 缓冲 =====
    always @(posedge clk_50m) begin
        if (pixel_tick)
            rgb_reg <= rgb_next;
    end

    assign rgb = rgb_reg;

endmodule
