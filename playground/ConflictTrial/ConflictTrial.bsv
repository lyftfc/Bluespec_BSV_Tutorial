package ConflictTrial;

interface Foo #(type t);
    method Action writeA (t val);
    method Action writeB (t val);
    method t readA ();
    method t readB ();
endinterface

typedef UInt #(32) U32_t;

module mkConflictTrial (Empty);

    U32_t count_limit = 20;

    Foo #(U32_t) instFoo <- mkFoo;
    Reg #(U32_t) cntA <- mkReg(0);
    Reg #(U32_t) cntB <- mkReg(0);

    rule rl_wr_a;
        instFoo.writeA(cntA);
        cntA <= cntA + 1;
    endrule

    rule rl_wr_b;
        instFoo.writeB(cntB);
        cntB <= cntB + 1;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule rl_rd_a_b;
        let aval = instFoo.readA;
        let bval = instFoo.readB;
        $display(aval, bval);
    endrule

    rule rl_stop (cntA >= count_limit || cntB >= count_limit);
        $finish;
    endrule

endmodule

module mkFoo (Foo #(t))
    provisos (Bits #(t, wt), Literal #(t));

    Reg #(t) ra <- mkReg(0);
    Reg #(t) rb <- mkReg(0);

    method Action writeA (t val);
        ra <= val;
    endmethod

    method Action writeB (t val);
        rb <= val;
    endmethod

    method t readA ();
        return ra;
    endmethod

    method t readB ();
        return rb;
    endmethod
endmodule

endpackage : ConflictTrial