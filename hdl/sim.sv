//
//  Copyright 2023 Antmicro
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Modifications Copyright 2026 Ignytion IO, under the same License.
//
// Co-simulation top: Renode's DPI IntegrationLibrary drives the SpinalHDL
// Apb3UartCtrl over APB3. The UART's transmit pin is wired back to its receive
// pin, so a byte written to DATA is serialised by the TX state machine, crosses
// the wire bit by bit and is reassembled by the RX state machine before Renode
// reads it back. The interrupt line is Renode GPIO input 0.
//
// Structure follows samples/apb3_completer_mem in antmicro/renode-dpi-examples.

`timescale 1ns / 1ps

import renode_pkg::renode_runtime;

module sim;
  parameter int ClockPeriod = 20;  // 50 MHz, the frequency the original demo used
  parameter int RenodeToCosimCount = 1;
  parameter int CosimToRenodeCount = 0;

  logic clk = 1;
  logic uart_irq;
  logic uart_line;

  renode_runtime runtime = new(RenodeToCosimCount, CosimToRenodeCount);
  renode #(
      .RenodeToCosimCount(RenodeToCosimCount),
      .RenodeInputsCount(1)
  ) renode (
      .runtime(runtime),
      .clk(clk),
      .renode_inputs(uart_irq),
      .renode_outputs()
  );

  renode_apb3_if #(
      .AddressWidth(20),
      .DataWidth(32)
  ) apb3 (clk);

  renode_apb3_requester renode_apb3_requester (
      .runtime(runtime),
      .bus(apb3)
  );

  initial begin
    runtime.connect_plus_args();
    renode.reset();
  end

  always @(posedge clk) begin
    // Blocks until Renode sends the next message.
    renode.receive_and_handle_message();
    if (!runtime.is_connected()) $finish;
  end

  always #(ClockPeriod / 2) clk = ~clk;

  Apb3UartCtrl dut (
      .io_apb_PADDR(apb3.paddr[4:0]),
      .io_apb_PSEL(apb3.pselx),
      .io_apb_PENABLE(apb3.penable),
      .io_apb_PREADY(apb3.pready),
      .io_apb_PWRITE(apb3.pwrite),
      .io_apb_PWDATA(apb3.pwdata),
      .io_apb_PRDATA(apb3.prdata),
      .io_uart_txd(uart_line),
      .io_uart_rxd(uart_line),
      .io_interrupt(uart_irq),
      .clk(clk),
      .reset(!apb3.presetn)
  );
  assign apb3.pslverr = 1'b0;

endmodule
