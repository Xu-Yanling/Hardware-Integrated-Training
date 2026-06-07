/*
module snake_graph (
    input wire clk, reset, newApple,
    input wire video_on, start,        // ← 接口不改
    input wire [3:0] dig0, dig1,
    input wire [3:0] btn,
    input wire [9:0] pix_x, pix_y,
    output reg [11:0] graph_rgb,
    output reg goodCollision, badCollision
);

    // =========================================================
    // 1. start 同步（不管外面是 button 还是 switch）
    // =========================================================
    reg start_ff1, start_ff2;
    always @(posedge clk) begin
        start_ff1 <= start;
        start_ff2 <= start_ff1;
    end
    wire start_sync = start_ff2;

    // =========================================================
    // 2. 速度控制 timer（干净版本）
    // =========================================================
    reg [23:0] timer;
    wire move_tick = (timer == 24'd5_000_000);

    always @(posedge clk or posedge reset) begin
        if (reset)
            timer <= 0;
        else if (!start_sync)
            timer <= 0;
        else if (move_tick)
            timer <= 0;
        else
            timer <= timer + 1;
    end

    // =========================================================
    // 3. 方向寄存器（button 本来就该干这个）
    // =========================================================
    reg [1:0] direction; // 00=Up 01=Left 10=Down 11=Right

    always @(posedge clk or posedge reset) begin
        if (reset)
            direction <= 2'b11;
        else if (start_sync) begin
            if (btn[0] && direction != 2'b11) direction <= 2'b01;
            else if (btn[1] && direction != 2'b01) direction <= 2'b11;
            else if (btn[2] && direction != 2'b10) direction <= 2'b00;
            else if (btn[3] && direction != 2'b00) direction <= 2'b10;
        end
    end
    // =========================================================
    // Apple 随机生成（LFSR）
    // =========================================================
    reg [9:0] appleX;
    reg [8:0] appleY;
    //reg apple_valid;
    // 16-bit LFSR
    reg [15:0] lfsr;
    
    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 16'hACE1;   // 随便一个非 0 种子
        else
            lfsr <= {lfsr[14:0],
                     lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            appleX <= 100;
            appleY <= 100;
            goodCollision <= 1'b0;
        end
        else begin 
            if (snakeX[0] == appleX && snakeY[0] == appleY) begin
                goodCollision <= 1'b1;
                size <= size + 1;
            end
            if (newApple) begin
                goodCollision <= 1'b0;  // 默认清零（脉冲）
                // 映射到 10x10 网格（避免贴边）
                appleX <= (lfsr[9:0]  % 62) * 10;  // 0~619
                appleY <= (lfsr[15:7] % 46) * 10;  // 0~459
                //apple_valid <= 1'b1;   // 新苹果出现
            end
        end
    end
    
    // =========================================================
    // 4. 蛇位置更新
    // =========================================================
    reg [6:0] size;
    reg [9:0] snakeX[0:127];
    reg [8:0] snakeY[0:127];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            size <= 5;
            for (i = 0; i < 128; i = i + 1) begin
                snakeX[i] <= 320 - i*10;
                snakeY[i] <= 240;
            end
        end 
        else if (start_sync && move_tick) begin
            for (i = 127; i > 0; i = i - 1)
                if (i < size) begin
                    snakeX[i] <= snakeX[i-1];
                    snakeY[i] <= snakeY[i-1];
                end

            case (direction)
                2'b00: snakeY[0] <= snakeY[0] - 10;
                2'b01: snakeX[0] <= snakeX[0] - 10;
                2'b10: snakeY[0] <= snakeY[0] + 10;
                2'b11: snakeX[0] <= snakeX[0] + 10;
            endcase  
        end
    end

    // =========================================================
    // 5. 字符显示（完全不依赖 start）
    // =========================================================
    wire score_on = (pix_y[9:5] == 0) && (pix_x[9:4] < 16);

    reg [6:0] char_addr;
    wire [3:0] row_addr = pix_y[4:1];
    wire [2:0] bit_addr = pix_x[3:1];
    wire [10:0] rom_addr = {char_addr, row_addr};
    wire [7:0] font_word;
    wire font_bit = font_word[~bit_addr];

    front_rom font_unit (
        .clk(clk),
        .addr(rom_addr),
        .data(font_word)
    );

    always @* begin
        case (pix_x[7:4])
            4'h0: char_addr = 7'h53;
            4'h1: char_addr = 7'h43;
            4'h2: char_addr = 7'h4F;
            4'h3: char_addr = 7'h52;
            4'h4: char_addr = 7'h45;
            4'h5: char_addr = 7'h3A;
            4'h6: char_addr = {3'b011, dig1};
            4'h7: char_addr = {3'b011, dig0};
            default: char_addr = 7'h00;
        endcase
    end

    // =========================================================
    // 6. 蛇显示
    // =========================================================
    reg snake_on;
    integer j;
    always @* begin
        snake_on = 0;
        for (j = 0; j < 128; j = j + 1)
            if (j < size)
                if (pix_x >= snakeX[j] && pix_x < snakeX[j]+10 &&
                    pix_y >= snakeY[j] && pix_y < snakeY[j]+10)
                    snake_on = 1;
    end
    // =========================================================
    // Apple 显示
    // =========================================================
    wire apple_on;
    
    assign apple_on =
        (pix_x >= appleX && pix_x < appleX + 10) &&
        (pix_y >= appleY && pix_y < appleY + 10);

    // =========================================================
    // 7. RGB 输出
    // =========================================================
    always @* begin
        if (!video_on)
            graph_rgb = 12'h000;
        else if (score_on)
            graph_rgb = font_bit ? 12'hFFF : 12'h00F;
        else if (snake_on)
            graph_rgb = 12'hF00;
        else if (apple_on)
            graph_rgb = 12'hFF0;
        else
            graph_rgb = 12'h0F0;
    end

endmodule
*/
module snake_graph (
    input wire clk, reset, newApple,
    input wire video_on, start,
    input wire [3:0] dig0, dig1,
    input wire [3:0] btn,
    input wire [9:0] pix_x, pix_y,
    output reg [11:0] graph_rgb,
    output reg goodCollision, badCollision
);

    // =========================================================
    // 1. start 同步
    // =========================================================
    reg start_ff1, start_ff2;
    always @(posedge clk) begin
        start_ff1 <= start;
        start_ff2 <= start_ff1;
    end
    wire start_sync = start_ff2;

    // =========================================================
    // 2. 速度控制 timer
    // =========================================================
    reg [23:0] timer;
    wire move_tick = (timer == 24'd5_000_000);

    always @(posedge clk or posedge reset) begin
        if (reset)
            timer <= 0;
        else if (!start_sync)
            timer <= 0;
        else if (move_tick)
            timer <= 0;
        else
            timer <= timer + 1;
    end

    // =========================================================
    // 3. 方向寄存器
    // =========================================================
    reg [1:0] direction; // 00=Up 01=Left 10=Down 11=Right
    always @(posedge clk or posedge reset) begin
        if (reset)
            direction <= 2'b11;
        else if (start_sync) begin
            if (btn[0] && direction != 2'b11) direction <= 2'b01;
            else if (btn[1] && direction != 2'b01) direction <= 2'b11;
            else if (btn[2] && direction != 2'b10) direction <= 2'b00;
            else if (btn[3] && direction != 2'b00) direction <= 2'b10;
        end
    end

    // =========================================================
    // 4. Apple 随机生成（LFSR）
    // =========================================================
    reg [9:0] appleX;
    reg [8:0] appleY;
    reg [15:0] lfsr;

    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0],
                     lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    wire eat_apple = (snakeX[0] == appleX && snakeY[0] == appleY);

    // eat_apple 脉冲
    wire eat_apple = (snakeX[0] == appleX && snakeY[0] == appleY);
    
    // goodCollision 输出（脉冲）
    always @(posedge clk or posedge reset) begin
        if (reset)
            goodCollision <= 0;
        else
            goodCollision <= eat_apple;
    end
    
    // 苹果坐标寄存器更新
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            appleX <= 100;
            appleY <= 100;
        end else if (newApple || eat_apple) begin
            appleX <= (lfsr[9:0]  % 62) * 10;
            appleY <= (lfsr[15:7] % 46) * 10;
        end
    end


    // =========================================================
    // 5. 蛇位置更新
    // =========================================================
    reg [6:0] size;
    reg [9:0] snakeX[0:127];
    reg [8:0] snakeY[0:127];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            size <= 5;
            for (i = 0; i < 128; i = i + 1) begin
                snakeX[i] <= 320 - i*10;
                snakeY[i] <= 240;
            end
        end
        else if (start_sync && move_tick) begin
            // 吃苹果后长身体
            if (eat_apple && size < 127)
                size <= size + 1;

            // 身体更新，从尾到头
            for (i = size-1; i > 0; i = i - 1) begin
                snakeX[i] <= snakeX[i-1];
                snakeY[i] <= snakeY[i-1];
            end

            // 头部移动
            case (direction)
                2'b00: snakeY[0] <= snakeY[0] - 10;
                2'b01: snakeX[0] <= snakeX[0] - 10;
                2'b10: snakeY[0] <= snakeY[0] + 10;
                2'b11: snakeX[0] <= snakeX[0] + 10;
            endcase
        end
    end

    // =========================================================
    // 6. 字符显示
    // =========================================================
    wire score_on = (pix_y[9:5] == 0) && (pix_x[9:4] < 16);
    reg [6:0] char_addr;
    wire [3:0] row_addr = pix_y[4:1];
    wire [2:0] bit_addr = pix_x[3:1];
    wire [10:0] rom_addr = {char_addr, row_addr};
    wire [7:0] font_word;
    wire font_bit = font_word[~bit_addr];

    front_rom font_unit (
        .clk(clk),
        .addr(rom_addr),
        .data(font_word)
    );

    always @* begin
        case (pix_x[7:4])
            4'h0: char_addr = 7'h53;
            4'h1: char_addr = 7'h43;
            4'h2: char_addr = 7'h4F;
            4'h3: char_addr = 7'h52;
            4'h4: char_addr = 7'h45;
            4'h5: char_addr = 7'h3A;
            4'h6: char_addr = {3'b011, dig1};
            4'h7: char_addr = {3'b011, dig0};
            default: char_addr = 7'h00;
        endcase
    end

    // =========================================================
    // 7. 蛇显示
    // =========================================================
    reg snake_on;
    integer j;
    always @* begin
        snake_on = 0;
        for (j = 0; j < 128; j = j + 1)
            if (j < size)
                if (pix_x >= snakeX[j] && pix_x < snakeX[j]+10 &&
                    pix_y >= snakeY[j] && pix_y < snakeY[j]+10)
                    snake_on = 1;
    end

    // =========================================================
    // 8. Apple 显示
    // =========================================================
    wire apple_on = (pix_x >= appleX && pix_x < appleX + 10) &&
                     (pix_y >= appleY && pix_y < appleY + 10);

    // =========================================================
    // 9. RGB 输出
    // =========================================================
    always @* begin
        if (!video_on)
            graph_rgb = 12'h000;
        else if (score_on)
            graph_rgb = font_bit ? 12'hFFF : 12'h00F;
        else if (snake_on)
            graph_rgb = 12'hF00;
        else if (apple_on)
            graph_rgb = 12'hFF0;
        else
            graph_rgb = 12'h0F0;
    end

endmodule
