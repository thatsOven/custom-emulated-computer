new method __nop() {
    if NOP_ALERT {
        new <Register> tmp = Register(None, RAM_ADDR_SIZE, False);
        tmp.data = this.programCounter.data.copy();
        tmp.dec();

        IO.out("WARNING: CPU executed NOP (address 0x", Compiler.bitArrayToHex(tmp.data, ceil(RAM_ADDR_SIZE / 4)), ").\n");
    }
}

new method __li(toFill) {
    new function li() {
        this.programCounter.write();
        this.mar.load();

        $call clock

        this.ram.write();
        toFill.load();

        this.programCounter.inc();
    }
    
    return li;
}

new method __fl(toFill) {
    new function fl() {
        this.instructionRegister.write();
        toFill.load();
    }
    
    return fl;
}

new method __lo(toFill) {
    new function lo() {
        this.programCounter.write();
        this.mar.load();

        $call clock

        this.ram.write();
        this.mar.load();

        $call clock

        this.ram.write();
        toFill.load();

        this.programCounter.inc();
    }

    return lo;
}

new method __st(toStore) {
    new function st() {
        this.programCounter.write();
        this.mar.load();

        $call clock

        this.ram.write();
        this.mar.load();

        $call clock

        toStore.write();
        this.ram.load();

        this.programCounter.inc();
    }

    return st;
}

new method __add() {
    this.alu.add();
    this.regX.load();
}

new method __sub() {
    this.alu.sub();
    this.regX.load();
}

new method __adsbi() {
    this.programCounter.write();
    this.mar.load();

    $call clock

    this.ram.write();
    this.regA.load();

    this.programCounter.inc();

    $call clock

    this.programCounter.write();
    this.mar.load();

    $call clock

    this.ram.write();
    this.regB.load();

    this.programCounter.inc();

    $call clock
}

new method __adi() {
    this.__adsbi();

    this.alu.add();
    this.regX.load();
}

new method __sbi() {
    this.__adsbi();

    this.alu.sub();
    this.regX.load();
}

new method __dli() {
    this.__li(this.display)();
    this.display.show();
}

new method __fdl() {
    this.__fl(this.display)();
    this.display.show();
}

new method __jmp() {
    this.programCounter.write();
    this.mar.load();

    $call clock

    this.ram.write();
    this.programCounter.load();
}

new method __jmi() {
    this.instructionRegister.write();
    this.programCounter.load();
}

new method __condJump(idx, fn) {
    new function condJump() {
        if this.flags.data[idx] {
            fn();
        }
    }
    
    return condJump;
}

new method __shiftRotate(toCall) {
    new function sr() {
        repeat this.instructionRegister.low.toDec() {
            toCall();
        }
    }

    return sr;
}

new method __mov(toWrite, toFill) {
    new function mov() {
        toWrite.write();
        toFill.load();
    }

    return mov;
}

new method __la(register) {
    new function la() {
        register.write();
        this.mar.load();

        $call clock

        this.ram.write();
        register.load();
    }

    return la;
}

new method __cpi() {
    this.__adsbi();
    this.alu.sub();
}

new method __ps(toPush) {
    new function ps() {
        this.sp.inc();

        $call clock

        this.sp.write();
        this.mar.load();

        $call clock

        toPush.write();
        this.ram.load();
    }

    return ps;
}

new method __pp(toPop) {
    new function pp() {
        this.sp.write();
        this.mar.load();

        $call clock

        this.ram.write();
        toPop.load();
        this.sp.dec();
    }

    return pp;
}

new method __jsr() {
    this.programCounter.inc();
    this.__ps(this.programCounter)();

    $call clock

    this.programCounter.dec();
    this.__jmp();
}

new method __rti() {
    this.__pp(this.programCounter)();

    this.__onInterrupt = False;
    this.interruptRegister.reset();
}

new method __fs(toWrite) {
    new function fs() {
        toWrite.write();
        this.gpu.load();
    }
    
    return fs;
}