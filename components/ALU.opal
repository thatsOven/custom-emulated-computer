enum FlagIndices {
    CARRY_OUT, ZERO, ODD
}

new class ALU : Component {
    new method __sum(b) {
        new Register result = Register(this.computer, len(this.computer.regA.data), False);
        new int carry = 0, aVal, bVal, dig, stAnd, ndAnd;

        for i in range(len(this.computer.regA.data)) {
            aVal = this.computer.regA.data[i];
            bVal = b.data[i];

            dig   = aVal ^ bVal;
            stAnd = aVal & bVal;

            ndAnd = dig & carry;
            dig ^= carry;

            result.data[i] = dig;
            carry = stAnd | ndAnd;
        }

        if result.data == [0 for _ in range(len(result.data))] {
            this.computer.flags.data[FlagIndices.ZERO] = 1;
        } else {
            this.computer.flags.data[FlagIndices.ZERO] = 0;
        }

        this.computer.flags.data[FlagIndices.ODD] = result.data[0];
        this.computer.flags.data[FlagIndices.CARRY_OUT] = carry;

        return result;
    }

    new method __bNeg() {
        new Register tmp = Register(None, BITS, False);
        tmp.data = this.computer.regB.data.copy();
        tmp.invert();
        tmp.inc();

        return tmp;
    }

    new method add() {
        this.__sum(this.computer.regB).write();
    }

    new method sub() {
        this.__sum(this.__bNeg()).write();
    }
}