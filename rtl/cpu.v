// cpu.v — single-cycle RV32I core
//
// Implements the RV32I base integer ISA (user level). FENCE is a no-op;
// ECALL/EBREAK halt the core with the exit code in a0 (x10).
// Memory interface is combinational-read (single cycle): the environment
// must return imem_rdata/dmem_rdata for the addresses presented this cycle.

module cpu (
    input  wire        clk,
    input  wire        reset,

    // instruction fetch
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // data access (byte-enable writes)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_we,
    input  wire [31:0] dmem_rdata,

    // ECALL/EBREAK stop the core; a0 carries the program's exit code
    output reg         halted,
    output wire [31:0] halt_code
);

    reg [31:0] pc;
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    wire [31:0] instr = imem_rdata;
    assign imem_addr = pc;

    // ---- decode -----------------------------------------------------------
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    wire [31:0] rv1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    wire [31:0] rv2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;
    localparam OP_SYSTEM = 7'b1110011;

    // ---- ALU --------------------------------------------------------------
    wire        is_imm_op = (opcode == OP_IMM);
    wire [31:0] alu_b     = is_imm_op ? imm_i : rv2;
    // instr[30] selects SUB/SRA; valid for R-type ops and immediate shifts,
    // never for ADDI/etc. where bit 30 is just part of the immediate
    wire        alt       = instr[30];
    wire [4:0]  shamt     = alu_b[4:0];
    // standalone so signedness survives; inside the ternary below, the
    // unsigned branch would coerce >>> into a logical shift
    wire [31:0] sra_out   = $signed(rv1) >>> shamt;

    reg [31:0] alu_out;
    always @* begin
        case (funct3)
            3'b000: alu_out = (!is_imm_op && alt) ? rv1 - alu_b : rv1 + alu_b;
            3'b001: alu_out = rv1 << shamt;
            3'b010: alu_out = ($signed(rv1) < $signed(alu_b)) ? 32'd1 : 32'd0;
            3'b011: alu_out = (rv1 < alu_b) ? 32'd1 : 32'd0;
            3'b100: alu_out = rv1 ^ alu_b;
            3'b101: alu_out = alt ? sra_out : (rv1 >> shamt);
            3'b110: alu_out = rv1 | alu_b;
            3'b111: alu_out = rv1 & alu_b;
        endcase
    end

    // ---- branch condition -------------------------------------------------
    reg take_branch;
    always @* begin
        case (funct3)
            3'b000:  take_branch = (rv1 == rv2);                     // beq
            3'b001:  take_branch = (rv1 != rv2);                     // bne
            3'b100:  take_branch = ($signed(rv1) <  $signed(rv2));   // blt
            3'b101:  take_branch = ($signed(rv1) >= $signed(rv2));   // bge
            3'b110:  take_branch = (rv1 <  rv2);                     // bltu
            3'b111:  take_branch = (rv1 >= rv2);                     // bgeu
            default: take_branch = 1'b0;
        endcase
    end

    // ---- data memory ------------------------------------------------------
    wire is_store = (opcode == OP_STORE);
    wire [31:0] mem_addr = rv1 + (is_store ? imm_s : imm_i);
    wire [1:0]  byte_off = mem_addr[1:0];
    assign dmem_addr = mem_addr;

    // stores: place data in the right byte lane, drive byte enables
    reg [31:0] st_data;
    reg [3:0]  st_be;
    always @* begin
        case (funct3[1:0])
            2'b00: begin st_data = {4{rv2[7:0]}};   st_be = 4'b0001 << byte_off; end // sb
            2'b01: begin st_data = {2{rv2[15:0]}};  st_be = 4'b0011 << byte_off; end // sh
            default: begin st_data = rv2;           st_be = 4'b1111;             end // sw
        endcase
    end
    assign dmem_wdata = st_data;
    assign dmem_we    = (!reset && !halted && is_store) ? st_be : 4'b0;

    // loads: pick the addressed bytes, extend per funct3
    wire [31:0] ld_shifted = dmem_rdata >> (8 * byte_off);
    reg [31:0] ld_data;
    always @* begin
        case (funct3)
            3'b000:  ld_data = {{24{ld_shifted[7]}},  ld_shifted[7:0]};  // lb
            3'b001:  ld_data = {{16{ld_shifted[15]}}, ld_shifted[15:0]}; // lh
            3'b100:  ld_data = {24'b0, ld_shifted[7:0]};                 // lbu
            3'b101:  ld_data = {16'b0, ld_shifted[15:0]};                // lhu
            default: ld_data = dmem_rdata;                               // lw
        endcase
    end

    // ---- next PC and writeback --------------------------------------------
    wire [31:0] pc_plus4 = pc + 32'd4;

    reg [31:0] next_pc;
    reg [31:0] wb_data;
    reg        wb_en;
    always @* begin
        next_pc = pc_plus4;
        wb_data = 32'b0;
        wb_en   = 1'b0;
        case (opcode)
            OP_LUI:    begin wb_en = 1'b1; wb_data = imm_u;    end
            OP_AUIPC:  begin wb_en = 1'b1; wb_data = pc + imm_u; end
            OP_JAL:    begin wb_en = 1'b1; wb_data = pc_plus4; next_pc = pc + imm_j; end
            OP_JALR:   begin wb_en = 1'b1; wb_data = pc_plus4; next_pc = (rv1 + imm_i) & 32'hFFFF_FFFE; end
            OP_BRANCH: if (take_branch) next_pc = pc + imm_b;
            OP_LOAD:   begin wb_en = 1'b1; wb_data = ld_data;  end
            OP_IMM:    begin wb_en = 1'b1; wb_data = alu_out;  end
            OP_REG:    begin wb_en = 1'b1; wb_data = alu_out;  end
            default:   ; // FENCE = nop; SYSTEM halts below
        endcase
    end

    assign halt_code = regs[10]; // a0

    always @(posedge clk) begin
        if (reset) begin
            pc     <= 32'b0;
            halted <= 1'b0;
        end else if (!halted) begin
            if (opcode == OP_SYSTEM) begin
                halted <= 1'b1;      // ecall/ebreak: end of program
            end else begin
                pc <= next_pc;
                if (wb_en && rd != 5'd0)
                    regs[rd] <= wb_data;
            end
        end
    end

endmodule
