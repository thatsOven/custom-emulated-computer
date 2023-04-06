new class Register : BUS {
    new method __init__(computer, bits, saveFlags = True) {
        this.computer  = computer;
        this.saveFlags = saveFlags;
        super().__init__(bits);
    }

    new method write() {
        this.computer.bus.load(this.data);
    }

    new method load() {
        super().load(this.computer.bus.data);
    }

    new method __checkFlags() {
        if this.saveFlags {
            if this.data == [0 for _ in range(this.bits)] {
                this.computer.flags.data[FlagIndices.ZERO] = 1;
            } else {
                this.computer.flags.data[FlagIndices.ZERO] = 0;
            }

            this.computer.flags.data[FlagIndices.ODD] = this.data[0];
        }
    }

    new method shiftR() {
        this.data = [0] + this.data[:-1];
        this.__checkFlags();
    }

    new method shiftL() {
        this.data = this.data[1:] + [0];
        this.__checkFlags();
    }

    new method rotateR() {
        this.data = [this.data[-1]] + this.data[:-1];
        this.__checkFlags();
    }

    new method rotateL() {
        this.data = this.data[1:] + [this.data[0]];
        this.__checkFlags();
    }

    new method invert() {
        for i in range(len(this.data)) {
            if this.data[i] == 0 {
                this.data[i] = 1;
            } else {
                this.data[i] = 0;
            }
        }
        
        this.__checkFlags();
    }

    new method inc() {
        new bool carry = False;

        for i in range(len(this.data)) {
            if this.data[i] == 0 {
                carry = False;
                this.data[i] = 1;
                break;
            } else {
                carry = True;
                this.data[i] = 0;
            }   
        }

        if this.saveFlags {
            this.computer.flags.data[FlagIndices.CARRY_OUT] = 1 if carry else 0;

            this.__checkFlags();
        }
    }

    new method dec() {
        if this.saveFlags {
            if this.data == [0 for _ in range(this.bits)] {
                this.computer.flags.data[FlagIndices.CARRY_OUT] = 1;
            } else {
                this.computer.flags.data[FlagIndices.CARRY_OUT] = 0;
            }
        }
        
        for i in range(len(this.data)) {
            if this.data[i] == 1 {
                this.data[i] = 0;
                break;
            } else {
                this.data[i] = 1;
            }
        }

        this.__checkFlags();
    }

    new method toDec(signed_ = False) {
        if signed_ {
            return -this.data[-1] * (2 ** (len(this.data) - 1)) + int("".join([str(bit) for bit in reversed(this.data[:-1])]), 2);
        } else {
            return int("".join([str(bit) for bit in reversed(this.data)]), 2);
        }
    }
}