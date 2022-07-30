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

    new method __getColor(data) {
        new int prc0 = COLOR_BITS * 2,
                prc1 = prc0 + COLOR_BITS;

        new dynamic blue  = data.data[:COLOR_BITS],
                    green = data.data[COLOR_BITS:prc0],
                    red   = data.data[prc0:prc1],
                    modif = data.data[prc1:];

        new int maxN = 2 ** (COLOR_BITS + GPU_MODIFIER_BITS) - 1;

        data.data = modif + blue;
        blue = int(Utils.translate(data.toDec(), 0, maxN, 0, 255));

        data.data = modif + green;
        green = int(Utils.translate(data.toDec(), 0, maxN, 0, 255));

        data.data = modif + red;
        red = int(Utils.translate(data.toDec(), 0, maxN, 0, 255));

        return (red, green, blue);
    }

    new method __get3Data() {
        this.computer.mar.load();

        $call clockExt

        this.computer.ram.write();
        new dynamic w = Register(this.computer, BITS, False);
        w.load();

        $call clockExt

        this.computer.mar.inc();

        $call clockExt

        this.computer.ram.write();
        new dynamic h = Register(this.computer, BITS, False);
        h.load();

        $call clockExt

        this.computer.mar.inc();

        $call clockExt

        this.computer.ram.write();
        new dynamic c = Register(this.computer, BITS, False);
        c.load();
        c = this.__getColor(c);

        return w.toDec(), h.toDec(), c;
    }

    new method load() {
        match this.mode.data {
            # pixel mode
            case [0, 0] {
                new <Register> tmp = Register(this.computer, BITS, False);
                tmp.load();

                this.frameBuffer.set_at((this.x.toDec(), this.y.toDec()), this.__getColor(tmp));
            } 
            # text mode
            case [1, 0] {
                new <Register> tmp = Register(this.computer, BITS, False);
                tmp.load();

                new int prc0 = CHAR_BITS + CHAR_COLOR_BITS,
                        prc1 = prc0 + CHAR_COLOR_BITS,
                        prc2 = prc1 + CHAR_COLOR_BITS,
                        prc3 = prc2 + CHAR_BG_COLOR_BITS,
                        prc4 = prc3 + CHAR_BG_COLOR_BITS;

                new dynamic ch      = tmp.data[:CHAR_BITS],
                            blue    = tmp.data[CHAR_BITS:prc0],
                            green   = tmp.data[prc0:prc1],
                            red     = tmp.data[prc1:prc2],
                            bgblue  = tmp.data[prc2:prc3],
                            bggreen = tmp.data[prc3:prc4],
                            bgred   = tmp.data[prc4:prc4 + CHAR_BG_COLOR_BITS];

                new int maxNCh = 2 ** CHAR_COLOR_BITS - 1,
                        maxNBg = 2 ** CHAR_BG_COLOR_BITS - 1;

                tmp.data = blue;
                blue = int(Utils.translate(tmp.toDec(), 0, maxNCh, 0, 255));

                tmp.data = green;
                green = int(Utils.translate(tmp.toDec(), 0, maxNCh, 0, 255));

                tmp.data = red;
                red = int(Utils.translate(tmp.toDec(), 0, maxNCh, 0, 255));

                tmp.data = bgblue;
                bgblue = int(Utils.translate(tmp.toDec(), 0, maxNBg, 0, 255));

                tmp.data = bggreen;
                bggreen = int(Utils.translate(tmp.toDec(), 0, maxNBg, 0, 255));

                tmp.data = bgred;
                bgred = int(Utils.translate(tmp.toDec(), 0, maxNBg, 0, 255));

                tmp.data = ch;
                ch = tmp.toDec();

                if ch in this.__charROM {
                    ch = this.__charROM[ch];
                } else {
                    ch = this.__charROM[0x20];
                }

                new dynamic startY = this.y.toDec() * 7,
                            startX = this.x.toDec() * 8;
                for y = startY, chY = 0; y < startY + 7; y++, chY++ {
                    for x = startX, chX = 0; x < startX + 8; x++, chX++ {
                        if ch[chY][chX] == 1 {
                            this.frameBuffer.set_at((x, y), (red, green, blue));
                        } else {
                            this.frameBuffer.set_at((x, y), (bgred, bggreen, bgblue));
                        }
                    }
                } 
            }
            # fill mode
            case [0, 1] {
                new dynamic w, h, c;
                unchecked: w, h, c = this.__get3Data();

                draw.rect(this.frameBuffer, c, (this.x.toDec(), this.y.toDec(), w, h));
            }
            # line mode
            case [1, 1] {
                new dynamic dstX, dstY, c;
                unchecked: dstX, dstY, c = this.__get3Data();

                draw.line(this.frameBuffer, c, (this.x.toDec(), this.y.toDec()), (dstX, dstY));
            }
        }
    }
}

new class SoundChip : Component {
    new method __init__(computer) {
        super().__init__(computer);

        this.frequency = Register(this.computer, SOUND_FREQ_BITS, False);
        this.amplitude = Register(this.computer, BITS - SOUND_FREQ_BITS, False);
        this.duration  = Register(this.computer, BITS, False);
    }

    new method load() {
        new <Register> tmp = Register(this.computer, BITS, False);
        tmp.load();

        $call clockExt

        tmp.write();
        this.computer.mar.load();

        $call clockExt

        this.computer.ram.write();

        for i = 0; i < len(this.frequency.data); i++ {
            this.frequency.data[i] = this.computer.bus.data[i];
        }

        for j = 0; i < BITS; i++, j++ {
            this.amplitude.data[j] = this.computer.bus.data[i];
        }

        $call clockExt

        this.computer.mar.inc();

        $call clockExt

        this.computer.ram.write();
        this.duration.load();
    }

    new method play() {
        new dynamic amp, freq, tmp, sample;
        amp = Utils.translate(this.amplitude.toDec(), 0, len(this.amplitude.data), 0, MAX_VOL_MULT);
        freq = this.frequency.toDec();

        if amp == 0 {
            return;
        }

        sample = numpy.arange(0, this.duration.toDec() / 1000, 1 / this.computer.graphics.frequencySample);
        tmp = audioMlt * amp * audio(2 * numpy.pi * (freq + MIN_FREQ) * sample);

        if this.computer.audioChs > 1 {
            this.computer.graphics.playWaveforms([numpy.repeat(tmp.reshape(tmp.size, 1), this.computer.audioChs, axis = 1)]);
        } else {
            this.computer.graphics.playWaveforms([tmp]);
        }
    }
}