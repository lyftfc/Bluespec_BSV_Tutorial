package Testbench;

import StmtFSM :: *;
import Cur_Cycle :: *;
import FIFO :: *;

import MyFifo :: *;

// Note: type name must have first letter in capital
typedef Int#(32) MyDT;

(* synthesize *)
module mkTestbench (Empty);

    Reg #(Int#(8)) sim_step <- mkReg(0);
    Reg #(Bool) sim_start <- mkReg(False);

    IfcMyFifo #(MyDT) dut  <- mkMyFifo_i32;
    FIFO #(MyDT) exDut <- mkSizedFifo_4_i32;

    mkAutoFSM (par
        sim_start <= True;
        while (sim_step < 6) sim_step <= sim_step + 1;
    endpar);

    rule dut_push (sim_start);
        MyDT val = extend(sim_step);
        dut.push(val);
        $display("%4d\tPushed %0x", cur_cycle, sim_step);
    endrule

    rule dut_pop (sim_start);
        let pop_val = dut.peek();
        dut.pop();
        $display("%4d\tPopped %0x", cur_cycle, pop_val);
    endrule

    rule exdut_push (sim_start);
        MyDT val = extend(sim_step);
        exDut.enq(val);
        $display("%4d\tEx Pushed %0x", cur_cycle, sim_step);
    endrule

    rule exdut_pop (sim_start);
        let pop_val = exDut.first();
        exDut.deq();
        $display("%4d\tEx Popped %0x", cur_cycle, pop_val);
    endrule

endmodule

// We only synthesize (i.e. emit Verilog module) for parameterized
// module as the original one is a "template" (has provisos)
(* synthesize *)
module mkMyFifo_i32 (IfcMyFifo #(MyDT));
    IfcMyFifo #(MyDT) m <- mkMyFifo(16);
    return m;
endmodule

(* synthesize *)
module mkSizedFifo_4_i32 (FIFO #(MyDT));
    FIFO #(MyDT) m <- mkSizedFIFO(4);
    return m;
endmodule

endpackage : Testbench
