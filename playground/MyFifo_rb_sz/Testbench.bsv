package Testbench;

import Cur_Cycle :: *;
import MyFifo :: *;

// Note: type name must has first letter in capital
typedef Int#(32) MyDT;

(* synthesize *)
module mkTestbench (Empty);

    Reg #(Int#(8)) sim_step <- mkReg(0);

    IfcMyFifo #(MyDT) dut  <- mkMyFifo_i32;

    rule every;
        let cyc <- cur_cycle;
        if (cyc >= 10 || sim_step >= 6) $finish;
    endrule

    rule dut_push;
        MyDT val = extend(sim_step);
        dut.push(val);
        $display("Pushed %0x", sim_step);
        sim_step <= sim_step + 1;
    endrule

    rule dut_pop;
        let pop_val = dut.peek();
        dut.pop();
        $display("Popped %0x", pop_val);
    endrule

endmodule

// We only synthesize (i.e. emit Verilog module) for parameterized
// module as the original one is a "template" (has provisos)
(* synthesize *)
module mkMyFifo_i32 (IfcMyFifo #(MyDT));
   IfcMyFifo #(MyDT) m <- mkMyFifo;
   return m;
endmodule

endpackage : Testbench