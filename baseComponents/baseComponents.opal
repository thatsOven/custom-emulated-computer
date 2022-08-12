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

$include os.path.join("HOME_DIR", "baseComponents", "Register.opal")

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

new class MemoryAddressRegister : Register {
    new method __init__(computer) {
        super().__init__(computer, RAM_ADDR_SIZE, False);
        this.writable = min(BITS, RAM_ADDR_SIZE);
    }

    new method load() {
        if len(this.computer.bus.data) < this.writable {
            for i = 0; i < len(this.computer.bus.data); i++ {
                this.data[i] = this.computer.bus.data[i];
            }

            for ; i < this.writable; i++ {
                this.data[i] = 0;
            }
        } else {
            for i = 0; i < len(this.computer.bus.data); i++ {
                this.data[i] = this.computer.bus.data[i];
            }
        }
    }

    new method loadMBSR() {
        new <Register> tmp = Register(computer, RAM_ADDR_SIZE - BITS, False);
        tmp.load();

        this.data = this.data[:BITS] + tmp.data;
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