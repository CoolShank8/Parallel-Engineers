-- 3 modes for sending prediction inputs

--  Order_Preserved, No_Order, RatePreserved, Absolute_Frame_Preserved

-- Only one that can drop predictions/inputs is Absolute_Frame_Preserved, inout has to reach by x tick on server or dropped

-- RatePreserved means inputs will not be run lets say 10 inputs in 1 frame, but 1 input per frame, prevents jitter But does not DROP packets



--- Order_Preserved Normal prediction should be used for things like Selection

