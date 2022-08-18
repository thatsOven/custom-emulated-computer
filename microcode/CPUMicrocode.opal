this.__microcode = (
    # NOP
    this.__nop,

    # LI? <value>
    this.__li(this.regX),
    this.__li(this.regY),
    this.__li(this.regZ),
    this.__li(this.regA),
    this.__li(this.regB),
    this.__li(this.display),

    # FL? <value inline>
    this.__fl(this.regX),
    this.__fl(this.regY),
    this.__fl(this.regZ),
    this.__fl(this.regA),
    this.__fl(this.regB),
    this.__fl(this.display),

    # LO? <address>
    this.__lo(this.regX),
    this.__lo(this.regY),
    this.__lo(this.regZ),
    this.__lo(this.regA),
    this.__lo(this.regB),
    this.__lo(this.display),

    # ST? <address>
    this.__st(this.regX),
    this.__st(this.regY),
    this.__st(this.regZ),
    this.__st(this.regA),
    this.__st(this.regB),
    this.__st(this.display),

    # ADD 
    this.__add,

    # SUB
    this.__sub,

    # ADI <val1, val2>
    this.__adi,

    # SBI <val1, val2>
    this.__sbi,

    # DPM <mode inline>
    this.__fl(this.display.mode),

    # DPL
    this.display.show,

    # DLI <value>
    this.__dli,

    # FDL <value inline>
    this.__fdl,

    # JMP <line>
    this.__jmp,

    # JMI <line inline>
    this.__jmi,

    # JC <line>
    this.__condJump(FlagIndices.CARRY_OUT, this.__jmp),

    # JCI <line inline>
    this.__condJump(FlagIndices.CARRY_OUT, this.__jmi),

    # JZ <line>
    this.__condJump(FlagIndices.ZERO, this.__jmp),

    # JZI <line inline>
    this.__condJump(FlagIndices.ZERO, this.__jmi),

    # IN? 
    this.regX.inc,
    this.regY.inc,
    this.regZ.inc,
    this.regA.inc,
    this.regB.inc,
    this.display.inc,

    # DC?
    this.regX.dec,
    this.regY.dec,
    this.regZ.dec,
    this.regA.dec,
    this.regB.dec,
    this.display.dec,

    # SL?
    this.__shiftRotate(this.regX.shiftL),
    this.__shiftRotate(this.regY.shiftL),
    this.__shiftRotate(this.regZ.shiftL),
    this.__shiftRotate(this.regA.shiftL),
    this.__shiftRotate(this.regB.shiftL),
    this.__shiftRotate(this.display.shiftL),

    # SR?
    this.__shiftRotate(this.regX.shiftR),
    this.__shiftRotate(this.regY.shiftR),
    this.__shiftRotate(this.regZ.shiftR),
    this.__shiftRotate(this.regA.shiftR),
    this.__shiftRotate(this.regB.shiftR),
    this.__shiftRotate(this.display.shiftR),

    # RL?
    this.__shiftRotate(this.regX.rotateL),
    this.__shiftRotate(this.regY.rotateL),
    this.__shiftRotate(this.regZ.rotateL),
    this.__shiftRotate(this.regA.rotateL),
    this.__shiftRotate(this.regB.rotateL),
    this.__shiftRotate(this.display.rotateL),

    # RR?
    this.__shiftRotate(this.regX.rotateR),
    this.__shiftRotate(this.regY.rotateR),
    this.__shiftRotate(this.regZ.rotateR),
    this.__shiftRotate(this.regA.rotateR),
    this.__shiftRotate(this.regB.rotateR),
    this.__shiftRotate(this.display.rotateR),

    # M??
    # MX?
    this.__mov(this.regX, this.regY),
    this.__mov(this.regX, this.regZ),
    this.__mov(this.regX, this.regA),
    this.__mov(this.regX, this.regB),
    this.__mov(this.regX, this.display),
    # MY?
    this.__mov(this.regY, this.regX),
    this.__mov(this.regY, this.regZ),
    this.__mov(this.regY, this.regA),
    this.__mov(this.regY, this.regB),
    this.__mov(this.regY, this.display),
    # MZ?
    this.__mov(this.regZ, this.regX),
    this.__mov(this.regZ, this.regY),
    this.__mov(this.regZ, this.regA),
    this.__mov(this.regZ, this.regB),
    this.__mov(this.regZ, this.display),
    # MA?
    this.__mov(this.regA, this.regX),
    this.__mov(this.regA, this.regY),
    this.__mov(this.regA, this.regZ),
    this.__mov(this.regA, this.regB),
    this.__mov(this.regA, this.display),
    # MB?
    this.__mov(this.regB, this.regX),
    this.__mov(this.regB, this.regY),
    this.__mov(this.regB, this.regZ),
    this.__mov(this.regB, this.regA),
    this.__mov(this.regB, this.display),
    # MD?
    this.__mov(this.display, this.regX),
    this.__mov(this.display, this.regY),
    this.__mov(this.display, this.regZ),
    this.__mov(this.display, this.regA),
    this.__mov(this.display, this.regB),

    # LA?
    this.__la(this.regX),
    this.__la(this.regY),
    this.__la(this.regZ),
    this.__la(this.regA),
    this.__la(this.regB),
    this.__la(this.display),

    # CMP
    this.alu.sub,

    # CPI <val1, val2>
    this.__cpi,

    # LOS <addr>
    this.__lo(this.sp),

    # LIS <value>
    this.__li(this.sp),

    # STS <addr>
    this.__st(this.sp),

    # INS
    this.sp.inc,

    # DCS
    this.sp.dec,

    # PS?
    this.__ps(this.regX),
    this.__ps(this.regY),
    this.__ps(this.regZ),
    this.__ps(this.regA),
    this.__ps(this.regB),
    this.__ps(this.display),

    # PP?
    this.__pp(this.regX),
    this.__pp(this.regY),
    this.__pp(this.regZ),
    this.__pp(this.regA),
    this.__pp(this.regB),
    this.__pp(this.display),

    # JSR
    this.__jsr,

    # RTS
    this.__pp(this.programCounter),

    # NE?
    this.regX.invert,
    this.regY.invert,
    this.regZ.invert,
    this.regA.invert,
    this.regB.invert,
    this.display.invert,

    # JOD <line>
    this.__condJump(FlagIndices.ODD, this.__jmp),

    # JDI <line inline>
    this.__condJump(FlagIndices.ODD, this.__jmi),

    # INT <interrupt inline>
    this.__fl(this.interruptRegister),

    # RTI 
    this.__rti,

    # LG? <address>
    this.__lo(this.gpu.x),
    this.__lo(this.gpu.y),

    # FG? <value>
    this.__li(this.gpu.x),
    this.__li(this.gpu.y),

    # GPM <mode inline>
    this.__fl(this.gpu.mode),

    # FS?
    this.__fs(this.regX),
    this.__fs(this.regY),
    this.__fs(this.regZ),
    this.__fs(this.regA),
    this.__fs(this.regB),
    this.__fs(this.display),

    # GXX
    this.__mov(this.regX, this.gpu.x),

    # GYY
    this.__mov(this.regY, this.gpu.y),

    # IG?
    this.gpu.x.inc,
    this.gpu.y.inc,

    # DG?
    this.gpu.x.dec,
    this.gpu.y.dec,

    # A??
    # AX?
    this.__addrStore(this.regX, this.regY),
    this.__addrStore(this.regX, this.regZ),
    this.__addrStore(this.regX, this.regA),
    this.__addrStore(this.regX, this.regB),
    this.__addrStore(this.regX, this.display),
    
    # AY?
    this.__addrStore(this.regY, this.regX),
    this.__addrStore(this.regY, this.regZ),
    this.__addrStore(this.regY, this.regA),
    this.__addrStore(this.regY, this.regB),
    this.__addrStore(this.regY, this.display),

    # SND <soundcode (amp + freq)>
    this.__snd,

    # SN?
    this.__sn(this.regX),
    this.__sn(this.regY),
    this.__sn(this.regZ),
    this.__sn(this.regA),
    this.__sn(this.regB),

    # WT?
    this.__wt(this.regX),
    this.__wt(this.regY),
    this.__wt(this.regZ),
    this.__wt(this.regA),
    this.__wt(this.regB),

    # FLS
    this.__fls,

    # M?S
    this.__movS(this.regX),
    this.__movS(this.regY),
    this.__movS(this.regZ),
    this.__movS(this.regA),
    this.__movS(this.regB)
);