package IfaceTrial;

import Vector::*;
import StmtFSM::*;
import Cur_Cycle::*;

interface MyReg #(type t);
    method Action wrReg (t v);
    method t rdReg ();
endinterface

interface Foo #(type t);
    interface Vector #(2, MyReg#(t)) myregs;
endinterface

typedef UInt #(32) U32_t;

module mkIfaceTrial (Empty);

    Foo #(U32_t) instFoo <- mkFoo_u32;
    Reg #(U32_t) cnt <- mkRegU;

    function Action dispCycle ();
        return action $display("Current cycle: %4d", cur_cycle); endaction;
    endfunction

    function Action toInit (Reg #(t) r) provisos (Literal #(t));
        return action
            dispCycle;
            r <= 0;
        endaction;
    endfunction

    mkAutoFSM (seq
        toInit(cnt);
        // Do not use for loop here: the iterator transition takes a single state/cycle!
        // for (cnt <= 0; cnt < 20; cnt <= cnt + 1) action endaction
        while (cnt < 20) action
            dispCycle;
            instFoo.myregs[0].wrReg(cnt);
            instFoo.myregs[1].wrReg(cnt);
            cnt <= cnt + 1;
        endaction
    endseq);

    rule prn_rd;
        $display(instFoo.myregs[0].rdReg, instFoo.myregs[1].rdReg);
    endrule

    let {rx, ry} <- mkTwoRegs(cnt);
    rule prn_rxy;
        $display("Count ", fshow(cnt), " Rx ", fshow(rx), " Ry ", fshow(ry));
    endrule

endmodule

function MyReg#(t) toIfaceReg (Reg #(t) r);
    return (interface MyReg;
        method Action wrReg (t v);
            r <= v;
        endmethod
        method t rdReg ();
            return r;
        endmethod
    endinterface);
endfunction

module mkFoo (Foo #(t))
    provisos (Bits #(t, wt), Literal #(t));

    Reg #(t) ra <- mkReg(0);
    Reg #(t) rb <- mkReg(0);

    // function Vector #(2, MyReg#(t)) mkMyRegsIfc (Vector #(2, Reg#(t)) vec_regs);
    //     // Vector #(0, MyReg#(t)) irn = nil;
    //     // let ir1 = cons(toIfaceReg(vec_regs[1]), irn);
    //     // let ir01 = cons(toIfaceReg(vec_regs[0]), ir1);
    //     // return ir01;
    //     return map(toIfaceReg, vec_regs);
    // endfunction
    // interface myregs = mkMyRegsIfc(cons(ra, cons(rb, nil)));

    // interface myregs = map(toIfaceReg, cons(ra, cons(rb, nil)));
    interface myregs = map(toIfaceReg, cons(ra, cons(rb, nil)));

endmodule

(* synthesize *)
module mkFoo_u32 (Foo #(U32_t));
    Foo #(U32_t) m <- mkFoo;
    return m;
endmodule

module mkTwoRegs #(Reg#(dt) oth_reg) (Tuple2 #(Reg#(dt), Reg#(dt)))
        provisos (Bits#(dt, dt_w), Arith#(dt));
    Reg#(dt) ra <- mkRegU;
    Reg#(dt) rb <- mkRegU;
    rule every;
        ra <= oth_reg + 1;
        rb <= oth_reg + 2;
    endrule
    return tuple2(ra, rb);
endmodule

endpackage : IfaceTrial