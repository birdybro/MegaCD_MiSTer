// Audio CDC via toggle-handshake.
// All cross-domain signals are single-bit with 2-flop synchronizers.
// Data is held stable between toggle and ack, guaranteeing safe capture.
//
// Max throughput: ~1 sample per round-trip (~4 sync stages). Changes
// during an in-flight handshake are coalesced. Not suitable for
// high-rate or bursty data.
//
// MIT License
//
// Copyright (c) 2026 Kevin Coleman
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

module audio_cdc #(
	parameter WIDTH = 16,
	parameter CHANNELS = 2
)(
	input  logic                       wclk,
	input  logic                       wreset,
	input  logic [CHANNELS*WIDTH-1:0]  data_in,

	input  logic                       rclk,
	input  logic                       rreset,
	output logic [CHANNELS*WIDTH-1:0]  data_out
);

localparam TOTAL = CHANNELS * WIDTH;

// ========== Write side (wclk) ==========

logic [TOTAL-1:0] w_data = '0;
logic w_toggle = '0;

// Sync r_ack into wclk
logic r_ack_sync1 = '0, r_ack_sync2 = '0;
always_ff @(posedge wclk) begin
	r_ack_sync1 <= r_ack;
	r_ack_sync2 <= r_ack_sync1;
end

logic w_busy;
assign w_busy = (w_toggle != r_ack_sync2);

logic data_changed;
assign data_changed = (data_in != w_data);

always_ff @(posedge wclk or posedge wreset) begin
	if (wreset) begin
		w_data    <= '0;
		w_toggle  <= '0;
	end else begin
		if (data_changed && !w_busy) begin
			w_data    <= data_in;
			w_toggle  <= ~w_toggle;
		end
	end
end

// ========== Read side (rclk) ==========

// Sync w_toggle into rclk
logic w_toggle_sync1 = '0, w_toggle_sync2 = '0;
always_ff @(posedge rclk) begin
	w_toggle_sync1 <= w_toggle;
	w_toggle_sync2 <= w_toggle_sync1;
end

logic r_ack = '0;
logic w_toggle_prev = '0;
logic r_new_data;
assign r_new_data = (w_toggle_sync2 != w_toggle_prev);

logic [TOTAL-1:0] r_data = '0;

always_ff @(posedge rclk or posedge rreset) begin
	if (rreset) begin
		r_ack         <= '0;
		w_toggle_prev <= '0;
		r_data        <= '0;
	end else begin
		if (r_new_data) begin
			r_data        <= w_data;
			w_toggle_prev <= w_toggle_sync2;
			r_ack         <= w_toggle_sync2;
		end
	end
end

assign data_out = r_data;

endmodule
