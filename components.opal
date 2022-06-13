new class Component {
    new method __init__(computer) {
        this.computer = computer;
    }
}

new class BUS {
    new method __init__(bits) {
        this.bits = bits;
        this.reset();
    }

    new method reset() {
        this.data = [0 for _ in range(this.bits)];
    }

    new method load(data) {
        if len(data) < len(this.data) {
            for i = 0; i < len(data); i++ {
                this.data[i] = data[i];
            }

            for ; i < len(this.data); i++ {
                this.data[i] = 0;
            }
        } else {
            for i = 0; i < len(this.data); i++ {
                this.data[i] = data[i];
            }
        }
    }
}

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

    new method __checkZero() {
        if this.saveFlags {
            if this.data == [0 for _ in range(this.bits)] {
                this.computer.flags.data[FlagIndices.ZERO] = 1;
            } else {
                this.computer.flags.data[FlagIndices.ZERO] = 0;
            }
        }
    }

    new method shiftR() {
        this.data = [0] + this.data[:-1];
        this.__checkZero();
    }

    new method shiftL() {
        this.data = this.data[1:] + [0];
        this.__checkZero();
    }

    new method rotateR() {
        this.data = [this.data[-1]] + this.data[:-1];
        this.__checkZero();
    }

    new method rotateL() {
        this.data = this.data[1:] + [this.data[0]];
        this.__checkZero();
    }

    new method invert() {
        for i in range(len(this.data)) {
            if this.data[i] == 0 {
                this.data[i] = 1;
            } else {
                this.data[i] = 0;
            }
        }
        
        if this.saveFlags {
            this.computer.flags.data[FlagIndices.ODD] = this.data[0];

            this.__checkZero();
        }
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
            this.computer.flags.data[FlagIndices.ODD] = this.data[0];

            this.__checkZero();
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

        if this.saveFlags {
            this.__checkZero();
            this.computer.flags.data[FlagIndices.ODD] = this.data[0];
        }
    }

    new method toDec(signed = False) {
        if signed {
            return -this.data[-1] * (2 ** (len(this.data) - 1)) + int("".join([str(bit) for bit in reversed(this.data[:-1])]), 2);
        } else {
            return int("".join([str(bit) for bit in reversed(this.data)]), 2);
        }
    }
}

enum FlagIndices {
    CARRY_OUT, ZERO, ODD
}

new class ALU : Component {
    new method __sum(b) {
        new <Register> result;
        result = Register(this.computer, len(this.computer.regA.data), False);
        new int carry = 0;

        for i in range(len(this.computer.regA.data)) {
            new int aVal = this.computer.regA.data[i],
                    bVal = b.data[i];

            new int dig   = aVal ^ bVal,
                    stAnd = aVal & bVal;

            new int ndAnd = dig & carry;
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
        new <Register> tmp = Register(None, BITS, False);
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

new class RAM : Component {
    new method __init__(computer, size) {
        super().__init__(computer);
        IO.out("Allocating virtual memory...\n");
        this.memory = [Register(computer, BITS, False) for _ in range(size)];
    }

    new method init(contents) {
        new int available = -1;

        for i in range(min(len(contents), len(this.memory))) {
            this.memory[i].data = contents[i];

            if i < this.computer.stackBase and i > this.computer.stackTop and contents[i] == [0 for _ in range(BITS)] {
                available++;
            }
        }

        if len(contents) < len(this.memory) {
            available += len(this.memory) - len(contents);
        }
        
        IO.out(f"RAM loaded. {available} words available ({available * BITS / 8} bytes)\n");
    }

    new method write() {
        this.memory[this.computer.mar.toDec()].write();
    }

    new method load() {
        this.memory[this.computer.mar.toDec()].load();
    }

    new method reset() {
        for address in this.memory {
            address.reset();
        }
    }
}

new class AlphaNumericDisplay : Register {
    new method __init__(computer) {
        this.mode = Register(computer, SCREEN_MODE_BITS, False);
        super().__init__(computer, BITS);
    }

    new method show() {
        if this.mode.data[1] == 0 {
            IO.out(this.toDec(bool(this.mode.data[0])));
        } else {
            IO.out(chr(this.toDec()));
        }
    }

    new method reset() {
        super().reset();
        this.mode.reset();
    }
}

new class InstructionRegister : Component {
    new method __init__(computer) {
        super().__init__(computer);
        this.instruction = Register(computer, INSTRUCTION_BITS, False);
        this.low         = Register(computer, BITS - INSTRUCTION_BITS, False);
    }

    new method write() {
        this.computer.bus.load(this.low.data);
    }

    new method load() {
        for i = 0; i < len(this.low.data); i++ {
            this.low.data[i] = this.computer.bus.data[i];
        }

        for j = 0; i < BITS; i++, j++ {
            this.instruction.data[j] = this.computer.bus.data[i];
        }
    }
}

new class StackPointer : Register {
    new method __init__(computer, bits) {
        super().__init__(computer, bits);
    }

    new method inc() {
        if STACK_PROTECTION and this.toDec() == this.computer.stackTop {
            IO.out("Stack overflow.\n");

            this.computer.stackError = True;
            return;
        }

        super().inc();
    }

    new method dec() {
        if STACK_PROTECTION and this.toDec() == this.computer.stackBase {
            IO.out("Stack pointer is out of bounds.\n");
            
            this.computer.stackError = True;
            return;
        }

        super().dec();
    }
}

new class GPU : Component {
    new method __init__(computer, resolution) {
        super().__init__(computer);

        this.x = Register(computer, BITS, False);
        this.y = Register(computer, BITS, False);

        this.frameBuffer = Surface((resolution.x, resolution.y));

        this.mode = Register(computer, GPU_MODE_BITS, False);

        $include os.path.join("HOME_DIR", "characterROM.opal")
    }

    new method load() {
        if this.mode.data == [0] {
            new <Register> tmp = Register(this.computer, COLOR_BITS * 3, False);
            tmp.load();

            new dynamic blue  = tmp.data[:COLOR_BITS],
                        green = tmp.data[COLOR_BITS:(COLOR_BITS * 2)],
                        red   = tmp.data[(COLOR_BITS * 2):];

            new int maxN = 2 ** COLOR_BITS - 1;

            tmp.data = blue;
            blue = int(Utils.translate(tmp.toDec(), 0, maxN, 0, 255));

            tmp.data = green;
            green = int(Utils.translate(tmp.toDec(), 0, maxN, 0, 255));

            tmp.data = red;
            red = int(Utils.translate(tmp.toDec(), 0, maxN, 0, 255));

            this.frameBuffer.set_at((this.x.toDec(), this.y.toDec()), (red, green, blue));
        } else {
            new <Register> tmp = Register(this.computer, BITS, False);
            tmp.load();

            new dynamic ch    = tmp.data[:CHAR_BITS],
                        blue  = tmp.data[CHAR_BITS:(CHAR_BITS + CHAR_COLOR_BITS)],
                        green = tmp.data[(CHAR_BITS + CHAR_COLOR_BITS):(CHAR_BITS + CHAR_COLOR_BITS * 2)],
                        red   = tmp.data[(CHAR_BITS + CHAR_COLOR_BITS * 2):];

            new int maxN = 2 ** CHAR_COLOR_BITS - 1;

            tmp.data = blue;
            blue = int(Utils.translate(tmp.toDec(), 0, maxN, 37, 255));

            tmp.data = green;
            green = int(Utils.translate(tmp.toDec(), 0, maxN, 37, 255));

            tmp.data = red;
            red = int(Utils.translate(tmp.toDec(), 0, maxN, 37, 255));

            tmp.data = ch;
            ch = tmp.toDec();

            if ch in this.__charROM {
                ch = this.__charROM[ch];
            } else {
                ch = this.__charROM[0x20];
            }

            new int startY = this.y.toDec() * 7,
                    startX = this.x.toDec() * 8;
            for y = startY, chY = 0; y < startY + 7; y++, chY++ {
                for x = startX, chX = 0; x < startX + 8; x++, chX++ {
                    if ch[chY][chX] == 1 {
                        this.frameBuffer.set_at((x, y), (red, green, blue));
                    } else {
                        this.frameBuffer.set_at((x, y), (0, 0, 0));
                    }
                }
            } 
        }
    }
}