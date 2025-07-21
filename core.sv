// RISC-V Core - Top level processor module
module riscv_core
    import riscv_defines::*;
(
    input  logic                clk,
    input  logic                rst_n,
    
    // Instruction memory interface
    output logic [XLEN-1:0]     imem_addr,
    input  logic [ILEN-1:0]     imem_data,
    output logic                imem_req,
    input  logic                imem_ready,
    
    // Data memory interface
    output logic [XLEN-1:0]     dmem_addr,
    output logic [XLEN-1:0]     dmem_wdata,
    input  logic [XLEN-1:0]     dmem_rdata,
    output logic                dmem_read,
    output logic                dmem_write,
    output logic [3:0]          dmem_byte_enable,
    input  logic                dmem_ready
);

    // Pipeline registers
    if_id_reg_t   if_id_reg, if_id_reg_next;
    id_ex_reg_t   id_ex_reg, id_ex_reg_next;
    ex_mem_reg_t  ex_mem_reg, ex_mem_reg_next;
    mem_wb_reg_t  mem_wb_reg, mem_wb_reg_next;
    
    // Program counter
    logic [XLEN-1:0] pc, pc_next;
    
    // Instruction fetch stage signals
    logic [XLEN-1:0] pc_plus_4;
    logic            stall_if;
    
    // Instruction decode stage signals
    logic [XLEN-1:0] immediate;
    control_t        control_signals;
    logic [REGFILE_ADDR_WIDTH-1:0] rs1_addr, rs2_addr, rd_addr;
    logic [XLEN-1:0] rs1_data, rs2_data;
    logic            stall_id;
    
    // Execute stage signals
    logic [XLEN-1:0] alu_operand_a, alu_operand_b;
    logic [XLEN-1:0] alu_result;
    logic            zero_flag;
    logic            take_branch;
    logic [XLEN-1:0] branch_target;
    logic            stall_ex;
    
    // Memory stage signals
    logic [XLEN-1:0] mem_read_data;
    logic            stall_mem;
    
    // Write back stage signals
    logic [XLEN-1:0] writeback_data;
    
    // Hazard detection and forwarding
    logic [1:0] forward_a, forward_b;
    logic       data_hazard;
    
    // Assign PC plus 4
    assign pc_plus_4 = pc + 32'd4;
    
    // Instruction memory interface
    assign imem_addr = pc;
    assign imem_req = !stall_if;
    
    //==========================================================================
    // INSTRUCTION FETCH STAGE
    //==========================================================================
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc <= 32'h0;
            if_id_reg <= '0;
        end else begin
            if (!stall_if) begin
                pc <= pc_next;
            end
            
            if (!stall_id) begin
                if_id_reg <= if_id_reg_next;
            end
        end
    end
    
    // PC next logic
    always_comb begin
        if (take_branch) begin
            pc_next = branch_target;
        end else begin
            pc_next = pc_plus_4;
        end
    end
    
    // IF/ID pipeline register
    always_comb begin
        if_id_reg_next.pc = pc;
        if_id_reg_next.instruction = imem_data;
        if_id_reg_next.valid = imem_ready && !stall_if;
    end
    
    //==========================================================================
    // INSTRUCTION DECODE STAGE
    //==========================================================================
    
    // Instruction decoder
    riscv_decoder u_decoder (
        .instruction(if_id_reg.instruction),
        .immediate(immediate),
        .control_signals(control_signals),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr)
    );
    
    // Register file
    riscv_regfile u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .write_enable(mem_wb_reg.control.reg_write && mem_wb_reg.valid),
        .rd_addr(mem_wb_reg.rd_addr),
        .rd_data(writeback_data)
    );
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            id_ex_reg <= '0;
        end else if (!stall_ex) begin
            id_ex_reg <= id_ex_reg_next;
        end
    end
    
    // ID/EX pipeline register
    always_comb begin
        id_ex_reg_next.pc = if_id_reg.pc;
        id_ex_reg_next.rs1_data = rs1_data;
        id_ex_reg_next.rs2_data = rs2_data;
        id_ex_reg_next.immediate = immediate;
        id_ex_reg_next.rd_addr = rd_addr;
        id_ex_reg_next.rs1_addr = rs1_addr;
        id_ex_reg_next.rs2_addr = rs2_addr;
        id_ex_reg_next.control = control_signals;
        id_ex_reg_next.valid = if_id_reg.valid && !stall_id;
    end
    
    //==========================================================================
    // EXECUTE STAGE
    //==========================================================================
    
    // ALU operand selection with forwarding
    always_comb begin
        case (forward_a)
            2'b00: alu_operand_a = id_ex_reg.rs1_data;
            2'b01: alu_operand_a = writeback_data;
            2'b10: alu_operand_a = ex_mem_reg.alu_result;
            default: alu_operand_a = id_ex_reg.rs1_data;
        endcase
        
        if (id_ex_reg.control.alu_op == ALU_AUIPC) begin
            alu_operand_a = id_ex_reg.pc;
        end
    end
    
    always_comb begin
        if (id_ex_reg.control.alu_src) begin
            alu_operand_b = id_ex_reg.immediate;
        end else begin
            case (forward_b)
                2'b00: alu_operand_b = id_ex_reg.rs2_data;
                2'b01: alu_operand_b = writeback_data;
                2'b10: alu_operand_b = ex_mem_reg.alu_result;
                default: alu_operand_b = id_ex_reg.rs2_data;
            endcase
        end
    end
    
    // ALU
    riscv_alu u_alu (
        .operand_a(alu_operand_a),
        .operand_b(alu_operand_b),
        .alu_op(id_ex_reg.control.alu_op),
        .result(alu_result),
        .zero_flag(zero_flag)
    );
    
    // Branch unit
    logic [XLEN-1:0] branch_rs1, branch_rs2;
    
    // Forward branch operands
    always_comb begin
        case (forward_a)
            2'b00: branch_rs1 = id_ex_reg.rs1_data;
            2'b01: branch_rs1 = writeback_data;
            2'b10: branch_rs1 = ex_mem_reg.alu_result;
            default: branch_rs1 = id_ex_reg.rs1_data;
        endcase
        
        case (forward_b)
            2'b00: branch_rs2 = id_ex_reg.rs2_data;
            2'b01: branch_rs2 = writeback_data;
            2'b10: branch_rs2 = ex_mem_reg.alu_result;
            default: branch_rs2 = id_ex_reg.rs2_data;
        endcase
    end
    
    riscv_branch_unit u_branch_unit (
        .rs1_data(branch_rs1),
        .rs2_data(branch_rs2),
        .branch_type(id_ex_reg.control.branch_type),
        .branch_enable(id_ex_reg.control.branch),
        .jump_enable(id_ex_reg.control.jump),
        .take_branch(take_branch)
    );
    
    // Branch target calculation
    always_comb begin
        if (id_ex_reg.control.jump && (id_ex_reg.rd_addr != 5'h0)) begin
            // JAL or JALR
            if (id_ex_reg.control.alu_src) begin
                // JALR: rs1 + immediate
                branch_target = alu_result;
            end else begin
                // JAL: PC + immediate
                branch_target = id_ex_reg.pc + id_ex_reg.immediate;
            end
        end else begin
            // Branch: PC + immediate
            branch_target = id_ex_reg.pc + id_ex_reg.immediate;
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ex_mem_reg <= '0;
        end else if (!stall_mem) begin
            ex_mem_reg <= ex_mem_reg_next;
        end
    end
    
    // EX/MEM pipeline register
    always_comb begin
        ex_mem_reg_next.alu_result = alu_result;
        ex_mem_reg_next.rs2_data = (forward_b == 2'b10) ? ex_mem_reg.alu_result :
                                   (forward_b == 2'b01) ? writeback_data :
                                   id_ex_reg.rs2_data;
        ex_mem_reg_next.rd_addr = id_ex_reg.rd_addr;
        ex_mem_reg_next.control = id_ex_reg.control;
        ex_mem_reg_next.valid = id_ex_reg.valid && !stall_ex;
    end
    
    //==========================================================================
    // MEMORY STAGE
    //==========================================================================
    
    // Data memory interface
    assign dmem_addr = ex_mem_reg.alu_result;
    assign dmem_read = ex_mem_reg.control.mem_read && ex_mem_reg.valid;
    assign dmem_write = ex_mem_reg.control.mem_write && ex_mem_reg.valid;
    
    // Memory data formatting
    always_comb begin
        case (ex_mem_reg.control.mem_type)
            MEM_BYTE: begin
                dmem_wdata = {4{ex_mem_reg.rs2_data[7:0]}};
                case (ex_mem_reg.alu_result[1:0])
                    2'b00: dmem_byte_enable = 4'b0001;
                    2'b01: dmem_byte_enable = 4'b0010;
                    2'b10: dmem_byte_enable = 4'b0100;
                    2'b11: dmem_byte_enable = 4'b1000;
                endcase
            end
            MEM_HALF: begin
                dmem_wdata = {2{ex_mem_reg.rs2_data[15:0]}};
                case (ex_mem_reg.alu_result[1])
                    1'b0: dmem_byte_enable = 4'b0011;
                    1'b1: dmem_byte_enable = 4'b1100;
                endcase
            end
            MEM_WORD: begin
                dmem_wdata = ex_mem_reg.rs2_data;
                dmem_byte_enable = 4'b1111;
            end
            default: begin
                dmem_wdata = ex_mem_reg.rs2_data;
                dmem_byte_enable = 4'b1111;
            end
        endcase
    end
    
    // Memory read data formatting
    always_comb begin
        case (ex_mem_reg.control.mem_type)
            MEM_BYTE: begin
                case (ex_mem_reg.alu_result[1:0])
                    2'b00: mem_read_data = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                    2'b01: mem_read_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: mem_read_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: mem_read_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            MEM_BYTE_U: begin
                case (ex_mem_reg.alu_result[1:0])
                    2'b00: mem_read_data = {24'h0, dmem_rdata[7:0]};
                    2'b01: mem_read_data = {24'h0, dmem_rdata[15:8]};
                    2'b10: mem_read_data = {24'h0, dmem_rdata[23:16]};
                    2'b11: mem_read_data = {24'h0, dmem_rdata[31:24]};
                endcase
            end
            MEM_HALF: begin
                case (ex_mem_reg.alu_result[1])
                    1'b0: mem_read_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: mem_read_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            MEM_HALF_U: begin
                case (ex_mem_reg.alu_result[1])
                    1'b0: mem_read_data = {16'h0, dmem_rdata[15:0]};
                    1'b1: mem_read_data = {16'h0, dmem_rdata[31:16]};
                endcase
            end
            MEM_WORD: begin
                mem_read_data = dmem_rdata;
            end
            default: begin
                mem_read_data = dmem_rdata;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem_wb_reg <= '0;
        end else begin
            mem_wb_reg <= mem_wb_reg_next;
        end
    end
    
    // MEM/WB pipeline register
    always_comb begin
        mem_wb_reg_next.alu_result = ex_mem_reg.alu_result;
        mem_wb_reg_next.mem_data = mem_read_data;
        mem_wb_reg_next.rd_addr = ex_mem_reg.rd_addr;
        mem_wb_reg_next.control = ex_mem_reg.control;
        mem_wb_reg_next.valid = ex_mem_reg.valid && (!ex_mem_reg.control.mem_read || dmem_ready);
    end
    
    //==========================================================================
    // WRITE BACK STAGE
    //==========================================================================
    
    // Writeback data selection
    always_comb begin
        case (mem_wb_reg.control.reg_write_src)
            2'b00: writeback_data = mem_wb_reg.alu_result;        // ALU result
            2'b01: writeback_data = mem_wb_reg.mem_data;          // Memory data
            2'b10: writeback_data = mem_wb_reg.alu_result + 32'd4; // PC + 4 (for JAL/JALR)
            default: writeback_data = mem_wb_reg.alu_result;
        endcase
    end
    
    //==========================================================================
    // HAZARD DETECTION AND FORWARDING UNIT
    //==========================================================================
    
    // Data forwarding logic
    always_comb begin
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // EX hazard (MEM stage to EX stage)
        if (ex_mem_reg.control.reg_write && ex_mem_reg.valid && 
            (ex_mem_reg.rd_addr != 5'h0) && (ex_mem_reg.rd_addr == id_ex_reg.rs1_addr)) begin
            forward_a = 2'b10;
        end
        
        if (ex_mem_reg.control.reg_write && ex_mem_reg.valid && 
            (ex_mem_reg.rd_addr != 5'h0) && (ex_mem_reg.rd_addr == id_ex_reg.rs2_addr)) begin
            forward_b = 2'b10;
        end
        
        // MEM hazard (WB stage to EX stage)
        if (mem_wb_reg.control.reg_write && mem_wb_reg.valid && 
            (mem_wb_reg.rd_addr != 5'h0) && (mem_wb_reg.rd_addr == id_ex_reg.rs1_addr) &&
            !(ex_mem_reg.control.reg_write && ex_mem_reg.valid && 
              (ex_mem_reg.rd_addr != 5'h0) && (ex_mem_reg.rd_addr == id_ex_reg.rs1_addr))) begin
            forward_a = 2'b01;
        end
        
        if (mem_wb_reg.control.reg_write && mem_wb_reg.valid && 
            (mem_wb_reg.rd_addr != 5'h0) && (mem_wb_reg.rd_addr == id_ex_reg.rs2_addr) &&
            !(ex_mem_reg.control.reg_write && ex_mem_reg.valid && 
              (ex_mem_reg.rd_addr != 5'h0) && (ex_mem_reg.rd_addr == id_ex_reg.rs2_addr))) begin
            forward_b = 2'b01;
        end
    end
    
    // Load-use hazard detection
    always_comb begin
        data_hazard = id_ex_reg.control.mem_read && id_ex_reg.valid &&
                     ((id_ex_reg.rd_addr == rs1_addr) || (id_ex_reg.rd_addr == rs2_addr)) &&
                     (id_ex_reg.rd_addr != 5'h0);
    end
    
    // Stall logic
    assign stall_if = stall_id || !imem_ready;
    assign stall_id = stall_ex || data_hazard;
    assign stall_ex = stall_mem;
    assign stall_mem = (ex_mem_reg.control.mem_read || ex_mem_reg.control.mem_write) && !dmem_ready;

endmodule
