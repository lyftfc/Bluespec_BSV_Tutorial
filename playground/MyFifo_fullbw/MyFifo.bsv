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

interface IfcMyFifoExt #(type dt);
    method Action push (dt d);
    method Bool canPush ();
    method dt peek ();
    method Action pop ();
    method Bool canPop ();
endinterface

module mkMyFifoExt (IfcMyFifoExt #(dt))
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

    Bool currIsFull = nextIndex(qTail) == qHead;
    Bool currIsEmpty = qHead == qTail;
    Bool pushRdy = currIsEmpty || !currIsFull;
    Bool popRdy = currIsFull || !currIsEmpty;

    method Action push (dt d); 
        data[qTail] <= d;
        qTail <= nextIndex(qTail);
    endmethod

    method Action pop ();
        qHead <= nextIndex(qHead);
    endmethod

    method dt peek ();
        return data[qHead];
    endmethod

    method Bool canPush ();
        return pushRdy;
    endmethod

    method Bool canPop ();
        return popRdy;
    endmethod
endmodule

module mkMyFifo (IfcMyFifo #(dt))
    provisos (Bits #(dt, wt));

    IfcMyFifoExt #(dt) instFifo <- mkMyFifoExt;

    method Action push (dt d) if (instFifo.canPush);
        instFifo.push(d);
    endmethod

    method Action pop () if (instFifo.canPop);
        instFifo.pop;
    endmethod

    method dt peek () if (instFifo.canPop);
        return instFifo.peek;
    endmethod

endmodule

endpackage : MyFifo