// SPDX-FileCopyrightText: 2026 Daniel Iglesias-Quilodrán <d.iglesias01@ufromail.cl>
// SPDX-License-Identifier: CERN-OHL-P-2.0
//
// Source location: https://github.com/iglesias-daniel/fpga-tinyml-cow-behavior
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
// PARTICULAR PURPOSE. Please see the CERN-OHL-P v2 for applicable conditions.
//
// Project     : fpga-tinyml-cow-behavior
// Module      : uart_tx
// Description : UART transmitter, 8N1 frame (1 start bit, 8 data bits
//               LSB first, no parity, 1 stop bit).
//
// Parameters  : CLK_FREQ_HZ - system clock frequency (Hz)
//               BAUD_RATE   - serial baud rate (bits/s)
//
// Notes       : Bit period = CLK_FREQ_HZ / BAUD_RATE clock cycles
//               (12 MHz / 3M -> 4 cycles, 0% baud error).

`default_nettype none

module uart_tx #(
    parameter int CLK_FREQ_HZ = 12_000_000,
    parameter int BAUD_RATE   = 3_000_000
) (
    input logic clk,
    input logic rst_n,
    input logic [7:0] data,
    input logic data_valid,
    output logic data_ready,
    output logic tx
);

    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
    localparam int CNT_W = $clog2(CLKS_PER_BIT);

    initial if (CLKS_PER_BIT < 2) $error("uart_tx: CLKS_PER_BIT must be >= 2");

    logic [CNT_W-1:0] baud_counter;
    logic [3:0] bits_left;
    logic [8:0] shift_reg;
    logic busy;
    logic baud_tick;

    assign busy = (bits_left != 4'd0);
    assign data_ready = ~busy;
    assign baud_tick = (baud_counter == '0);

    /* Generación del tick para obtener los baudios */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) baud_counter <= CNT_W'(CLKS_PER_BIT-1);
        else if (!busy || baud_tick) baud_counter <= CNT_W'(CLKS_PER_BIT-1);
        else baud_counter <= baud_counter - 1'b1;
    end

    /* Funcionamiento del shift register */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '1;
            bits_left <= '0;
        end else if (!busy) begin
            if (data_valid) begin
                shift_reg <= {data, 1'b0};
                bits_left <= 4'd10;
            end
        end else if (baud_tick) begin
            shift_reg <= {1'b1, shift_reg[8:1]};
            bits_left <= bits_left -1'b1;
        end
    end

    assign tx = shift_reg[0];
endmodule

`default_nettype wire