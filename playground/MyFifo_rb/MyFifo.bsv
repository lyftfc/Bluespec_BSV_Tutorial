package MyFifo;

import Vector :: *;

typedef 16 FifoDepthT;
typedef UInt#(32) SizeT;

// Just trying
typedef struct {
    UInt #(32) x;
} Apples deriving (Literal, Arith);

interface IfcMyFifo #(type dt);
    method Action push (dt d);
    method dt peek ();
    method Action pop ();
endinterface

module mkMyFifo (IfcMyFifo #(dt))
    provisos (Bits #(dt, wt));

    SizeT cDepth = fromInteger(valueOf(FifoDepthT));

    Reg #(SizeT) qHead  <- mkReg(0);    // Slot for next dequeuing
    Reg #(SizeT) qTail  <- mkReg(0);    // Empty slot for next enqueuing
    // Use Monadic Replicate to initialize all vector elements
    Vector #(FifoDepthT, Reg#(dt)) data <- replicateM(mkReg(?));

    function SizeT nextIndex (SizeT i);
        if (i == cDepth - 1) return 0;
        else return i + 1;
    endfunction

    function Bool currIsEmpty ();
        return qHead == qTail;
    endfunction

    function Bool currIsFull ();
        return nextIndex(qTail) == qHead;
    endfunction

    // Push and pop are in conflict as currIsFull/currIsEmpty depends on state of data/qHead/qTail, which they modifies
    method Action push (dt d) if (!currIsFull()); 
        data[qTail] <= d;
        qTail <= nextIndex(qTail);
    endmethod

    method Action pop () if (!currIsEmpty());
        qHead <= nextIndex(qHead);
    endmethod

    method dt peek () if (!currIsEmpty());
        return data[qHead];
    endmethod

endmodule

endpackage : MyFifo