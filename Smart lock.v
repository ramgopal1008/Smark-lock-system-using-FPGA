`timescale 1ns / 1ps

module debounce(
    input clk,
    input btn,
    output reg debounced
);
    reg [19:0] count = 0;
    reg btn_sync_0, btn_sync_1, btn_stable;

    always @(posedge clk) begin
        btn_sync_0 <= btn;
        btn_sync_1 <= btn_sync_0;

        if (btn_sync_1 == btn_stable)
            count <= 0;
        else begin
            count <= count + 1;
            if (count == 20'd1000000) begin
                btn_stable <= btn_sync_1;
                count <= 0;
            end
        end
    end

    reg btn_prev = 0;
    always @(posedge clk) begin
        btn_prev <= btn_stable;
        debounced <= (btn_stable && !btn_prev);
    end
endmodule

module trails(
    input [3:0] pin, npin,
    input clk, enter, rst, rst_pin,
    output reg complete = 0,
    output reg npin_out = 0,
    output reg access_denied = 0,
    output reg game_over = 0
);
    reg [3:0] pstate = 0, nstate = 0;
    reg [3:0] rpin = 4'b1101;
    reg [1:0] i = 0;

    wire enter_db;
    wire rst_pin_db;

    debounce db_enter (
        .clk(clk),
        .btn(enter),
        .debounced(enter_db)
    );

    debounce db_rst_pin (
        .clk(clk),
        .btn(rst_pin),
        .debounced(rst_pin_db)
    );

    parameter start        = 4'b0000;
    parameter wait_enter   = 4'b0001;
    parameter check        = 4'b0010;
    parameter fail         = 4'b0011;
    parameter success      = 4'b0100;
    parameter access_deny  = 4'b0101;
    parameter stop         = 4'b0110;
    parameter pwchange     = 4'b0111;

    always @(*) begin
        if (pstate == start) begin
            if (enter_db == 1)
                nstate = check;
            else
                nstate = wait_enter;
        end

        else if (pstate == wait_enter) begin
            if (enter_db == 1)
                nstate = check;
            else
                nstate = wait_enter;
        end

        else if (pstate == check) begin
            if (pin == rpin)
                nstate = success;
            else
                nstate = fail;
        end

        else if (pstate == success) begin
            if (rst_pin_db == 1)
                nstate = pwchange;
            else
                nstate = stop;
        end

        else if (pstate == pwchange) begin
            if (rst_pin_db == 0)
                nstate = start;
            else
                nstate = pwchange;
        end

        else if (pstate == fail) begin
            if (i == 2)
                nstate = access_deny;
            else
                nstate = start;
        end

        else if (pstate == access_deny) begin
            nstate = access_deny;
        end

        else if (pstate == stop) begin
            nstate = start;
        end

        else begin
            nstate = start;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= start;
            rpin <= 4'b1101;
            i <= 0;
            complete <= 0;
            npin_out <= 0;
            access_denied <= 0;
            game_over <= 0;
        end else begin
            pstate <= nstate;

            case (nstate)
                start, wait_enter, check: begin
                    complete <= 0;
                    npin_out <= 0;
                    access_denied <= 0;
                    game_over <= 0;
                end

                success: begin
                    complete <= 0;
                    npin_out <= 0;
                    access_denied <= 0;
                    game_over <= 0;
                    i <= 0;
                end

                pwchange: begin
                    complete <= 0;
                    npin_out <= 1;
                    access_denied <= 0;
                    game_over <= 0;
                    rpin <= npin;
                end

                fail: begin
                    i <= i + 1;
                    complete <= 0;
                    npin_out <= 0;
                    access_denied <= 0;
                    game_over <= 0;
                end

                access_deny: begin
                    complete <= 0;
                    npin_out <= 0;
                    access_denied <= 1;
                    game_over <= 1;
                end

                stop: begin
                    complete <= 1;
                    npin_out <= 0;
                    access_denied <= 0;
                    game_over <= 0;
                end

                default: begin
                    complete <= 0;
                    npin_out <= 0;
                    access_denied <= 0;
                    game_over <= 0;
                end
            endcase
        end
    end
endmodule
