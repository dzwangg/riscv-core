// tb.v — simulation environment: 64 KiB RAM + console MMIO
//
// Memory map:
//   0x0000_0000 .. 0x0000_FFFF   RAM (code + data + stack), PC resets to 0
//   0x1000_0000                  console: a byte stored here prints to stdout
//
// Plusargs:
//   +hex=<file>      program image (one 32-bit word per line, required)
//   +cycles=<n>      cycle limit before TIMEOUT (default 1,000,000)
//   +vcd=<file>      dump a VCD waveform
//
// The program ends with ECALL; the exit code in a0 is printed as "EXIT <n>"
// on stderr — the program's own console output goes to stdout, so the two
// streams can't be confused (or forged by a program printing "EXIT 0").

`timescale 1ns / 1ps

module tb;

    reg clk = 1'b0;
    reg reset = 1'b1;
    always #5 clk = ~clk;

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_we;
    wire        halted;
    wire [31:0] halt_code;

    cpu dut (
        .clk(clk), .reset(reset),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .halted(halted), .halt_code(halt_code)
    );

    // 64 KiB unified RAM, combinational read on both ports
    reg [31:0] mem [0:16383];
    assign imem_rdata = mem[imem_addr[15:2]];
    assign dmem_rdata = mem[dmem_addr[15:2]];

    localparam CONSOLE_ADDR = 32'h1000_0000;
    localparam STDERR       = 32'h8000_0002;

    always @(posedge clk) begin
        if (|dmem_we) begin
            if (dmem_addr == CONSOLE_ADDR) begin
                $write("%c", dmem_wdata[7:0]);
            end else begin
                if (dmem_we[0]) mem[dmem_addr[15:2]][7:0]   <= dmem_wdata[7:0];
                if (dmem_we[1]) mem[dmem_addr[15:2]][15:8]  <= dmem_wdata[15:8];
                if (dmem_we[2]) mem[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
                if (dmem_we[3]) mem[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
            end
        end
    end

    integer max_cycles;
    integer cycles = 0;
    reg [8*256:1] hexfile;
    reg [8*256:1] vcdfile;
    integer j;

    initial begin
        if (!$value$plusargs("hex=%s", hexfile)) begin
            $fdisplay(STDERR, "ERROR: no program (+hex=<file>)");
            $finish;
        end
        if (!$value$plusargs("cycles=%d", max_cycles)) max_cycles = 1000000;
        for (j = 0; j < 16384; j = j + 1) mem[j] = 32'b0;
        $readmemh(hexfile, mem);
        if ($value$plusargs("vcd=%s", vcdfile)) begin
            $dumpfile(vcdfile);
            $dumpvars(0, tb);
        end
        repeat (2) @(posedge clk);
        reset <= 1'b0;
    end

    always @(posedge clk) begin
        if (!reset) begin
            if (halted) begin
                $fdisplay(STDERR, "EXIT %0d", halt_code);
                $finish;
            end
            cycles = cycles + 1;
            if (cycles >= max_cycles) begin
                $fdisplay(STDERR, "TIMEOUT after %0d cycles (pc=%08h)", cycles, imem_addr);
                $finish;
            end
        end
    end

endmodule
