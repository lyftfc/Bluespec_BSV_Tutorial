package Testbench;

import Cur_Cycle :: *;
import MyFifo :: *;
import FIFO :: *;

// Note: type name must has first letter in capital
typedef Int#(32) MyDT;

(* synthesize *)
module mkTestbench (Empty);

    Reg #(Int#(8)) sim_step <- mkReg(0);

    IfcMyFifo #(MyDT) dut  <- mkMyFifo_i32;
    FIFO #(MyDT) exDut <- mkSizedFifo_4_i32;

    rule every;
        let cyc <- cur_cycle;
        if (cyc >= 10 || sim_step >= 6) $finish;
    endrule

    // function Rules fn_genDutPush (IfcMyFifo #(MyDT) mydut);
    //     return (rules 
    //         rule mydut_push;
    //             MyDT val = extend(sim_step);
    //             mydut.push(val);
    //             $display("Pushed %0x", sim_step);
    //             sim_step <= sim_step + 1;
    //         endrule
    //     endrules);
    // endfunction
    // let rl_dut_push = emptyRules;
    // rl_dut_push = rJoinConflictFree(rl_dut_push, fn_genDutPush(dut));

    // (* conflict_free = "dut_push, dut_pop" *)
    // rule dut_push;
    //     MyDT val = extend(sim_step);
    //     dut.push(val);
    //     $display("Pushed %0x", sim_step);
    //     sim_step <= sim_step + 1;
    // endrule
    // rule dut_pop;
    //     let pop_val = dut.peek();
    //     dut.pop();
    //     $display("Popped %0x", pop_val);
    // endrule

    rule dut_push_n_pop;
        if (sim_step >= 2) begin
            let pop_val = dut.peek;
            dut.pop;
            $display("Popped %0x", pop_val);
        end
        MyDT val = extend(sim_step);
        dut.push(val);
        $display("Pushed %0x", sim_step);
        sim_step <= sim_step + 1;
    endrule

    rule exdut_push;
        MyDT val = extend(sim_step);
        exDut.enq(val);
        $display("Ex Pushed %0x", sim_step);
    endrule

    rule exdut_pop;
        let pop_val = exDut.first();
        exDut.deq();
        $display("Ex Popped %0x", pop_val);
    endrule

endmodule

// We only synthesize (i.e. emit Verilog module) for parameterized
// module as the original one is a "template" (has provisos)
(* synthesize *)
module mkMyFifo_i32 (IfcMyFifo #(MyDT));
    IfcMyFifo #(MyDT) m <- mkMyFifo;
    return m;
endmodule

(* synthesize *)
module mkSizedFifo_4_i32 (FIFO #(MyDT));
    FIFO #(MyDT) m <- mkSizedFIFO(4);
    return m;
endmodule

endpackage : Testbench