package MyFifo;

import Vector :: *;

typedef 16 FifoDepthT;
typedef Int#(32) SizeT;

interface IfcMyFifo #(type dt);
    method Action push (dt d);
    method dt peek ();
    method Action pop ();
endinterface

module mkMyFifo (IfcMyFifo #(dt))
    provisos (Bits #(dt, wt));

    SizeT cDepth = valueOf(FifoDepthT);

    Reg #(Bool) isEmpty <- mkReg(True);
    Reg #(Bool) isFull  <- mkReg(False);
    Reg #(Bool) justPushed  <- mkReg(False);
    Reg #(Bool) justPopped  <- mkReg(False);
    Reg #(SizeT) elemCount  <- mkReg(0);
    // Use Monadic Replicate to initialize all vector elements
    Vector #(FifoDepthT, Reg#(dt)) data <- replicateM(mkReg(?));

    function SizeT currElemCount ();
        SizeT netChange = 0;
        if (justPushed) netChange = netChange + 1;
        if (justPopped) netChange = netChange - 1;
        return elemCount + netChange;
    endfunction

    function Bool currIsEmpty ();
        return currElemCount() == 0;
    endfunction

    function Bool currIsFull ();
        return currElemCount() >= cDepth;
    endfunction

    rule upd_count (justPopped || justPushed);
        elemCount <= currElemCount();
    endrule

    method Action push (dt d) if (!currIsFull()); 
        data <= d;
        justPushed <= True; // TODO: This is INCORRECT! No one is resetting it.
        if (elemCount + 1 == c_my_fifo_size)
            isFull <= True;
    endmethod

    method Action pop () if (!currIsEmpty());
        isFull <= False;
        elemCount <= elemCount - 1;
        if (elemCount - 1 == 0)
            isEmpty <= True;
    endmethod

    method dt peek () if (!currIsEmpty());
        return data;
    endmethod

endmodule

endpackage : MyFifo