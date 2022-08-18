package opal:   import *;
package time:   import sleep;
package sys:    import argv;
package math:   import ceil;
package scipy:  import signal;
package timeit: import default_timer;
package pygame: import Surface, transform, draw, mixer;
import numpy;

new <Vector> RESOLUTION = Vector(256, 256);

new int BITS                  = 16,
        RAM_ADDR_SIZE         = 20,
        SCREEN_MODE_BITS      = 2,
        FLAGS_QTY             = 3,
        INSTRUCTION_BITS      = 8,
        INTERRUPT_BITS        = 4,
        GPU_MODE_BITS         = 2,
        COLOR_BITS            = 5,
        GPU_MODIFIER_BITS     = 1,
        CHAR_BITS             = 7,
        CHAR_COLOR_BITS       = 2,
        CHAR_BG_COLOR_BITS    = 1,
        SOUND_FREQ_BITS       = 13,
        MAX_VOL_MULT          = 500,
        FREQUENCY_SAMPLE      = 30000,
        SAWTOOTH_WIDTH_BITS   = 4,
        SAWTOOTH_AMP_BITS     = 4,
        SQUARE_PWM_WIDTH_BITS = 4,
        SQUARE_AMP_BITS       = 4,
        SOUND_CHANNELS        = 256;

new float CLOCK_PULSE_DURATION = 0,
          SCREEN_SCALE         = 1,
          SAWTOOTH_MULT        = 2.5;

new bool HEX_DUMP                  = False,
         STACK_PROTECTION          = True,
         NOP_ALERT                 = True,
         UNKNOWN_OPCODE_ALERT      = True,
         HALT_ON_UNKNOWN           = True,
         UNHANDLED_INTERRUPT_ALERT = False,
         SIMPLE_AUDIO              = False,
         ALWAYS_NOP_WAIT           = False;

$macro clock
    sleep(CLOCK_PULSE_DURATION);
$end

$include os.path.join("HOME_DIR", "compiler", "Compiler.opal")
$include os.path.join("HOME_DIR", "baseComponents", "baseComponents.opal")
$includeDirectory os.path.join("HOME_DIR", "components")

new class Computer {
    $include os.path.join("HOME_DIR", "microcode", "microcodeMethods.opal")

    new method __init__() {
        this.bus = BUS(BITS);

        this.regX = Register(this, BITS);
        this.regY = Register(this, BITS);
        this.regZ = Register(this, BITS);
        this.regA = Register(this, BITS);
        this.regB = Register(this, BITS);

        this.flags = Register(this, FLAGS_QTY, False);
        this.alu = ALU(this);

        this.mar = MemoryAddressRegister(this);
        this.sp  = StackPointer(this, RAM_ADDR_SIZE);
        this.ram = RAM(this, 2 ** RAM_ADDR_SIZE);

        this.display = AlphaNumericDisplay(this);

        IO.out("Initializing graphics...\n");

        this.gpu = GPU(this, RESOLUTION);
        this.screenSize = (RESOLUTION * SCREEN_SCALE).getIntCoords();
        this.graphics = Graphics(this.screenSize, None, caption = "Emulated computer screen", frequencySample = FREQUENCY_SAMPLE);
        this.graphics.drawLoop = this.__draw;
        this.graphics.event(KEYDOWN)(this.__keydown);
        this.graphics.event(QUIT)(this.__quit);

        this.audioChs = this.graphics.getAudioChs()[2];

        this.soundChip = SoundChip(this);

        this.programCounter      = Register(this, RAM_ADDR_SIZE, False);
        this.instructionRegister = InstructionRegister(this);

        this.interruptRegister = Register(this, INTERRUPT_BITS, False);
        this.__onInterrupt     = False;
        this.interruptHandlers = {};

        # data used for stack protection
        this.stackBase  = 0;
        this.stackTop   = 0;
        this.stackError = False;

        this.waiting     = False;
        this.waitAddress = None;
        this.waitEnd     = None;

        this.keyBufferAddr = 2 ** RAM_ADDR_SIZE - 1;

        $include os.path.join("HOME_DIR", "microcode", "CPUMicrocode.opal")
    }

    new method generateInterrupt(code) {
        this.interruptRegister.data = Compiler.fill(Compiler.decimalToBitarray(code), INTERRUPT_BITS);
    }

    new method __keydown(event) {
        this.generateInterrupt(1);
        this.ram.memory[this.keyBufferAddr].data = Compiler.fill(Compiler.decimalToBitarray(event.key));
    }

    new method __quit(event = None) {
        IO.out("CPU Halted.\n");
        quit;
    }

    new method __memSwap(bufPos, fromReg, toAddr) {
        this.ram.memory[bufPos].data = fromReg.data.copy();
        fromReg.data = this.ram.memory[toAddr].data.copy();
        this.ram.memory[toAddr].data = this.ram.memory[bufPos].data.copy();
    }

    new method getProgramCounter() {
        if this.waiting {
            return this.ram.memory[this.waitAddress];
        } else {
            return this.programCounter;
        }
    }

    new method __handleInstruction() {
        new int instruction = this.instructionRegister.instruction.toDec();

        # 255 = HLT
        if instruction == 255 or this.stackError {
            this.__quit();
        } elif instruction == 254 {
            this.graphics.restore();
            transform.scale(this.gpu.frameBuffer, (this.screenSize.x, this.screenSize.y), this.graphics.screen);
            this.graphics.rawUpdate();
            return;
        } elif instruction == 253 {
            this.graphics.loopOnly();
            return;
        } elif instruction >= len(this.__microcode) and UNKNOWN_OPCODE_ALERT {
            new <Register> tmp = Register(None, RAM_ADDR_SIZE, False);
            tmp.data = this.getProgramCounter().data.copy();
            tmp.dec();

            IO.out(
                "WARNING: Unrecognized opcode (0x",
                Compiler.bitArrayToHex(this.instructionRegister.instruction.data, ceil(INSTRUCTION_BITS / 4)),
                ") at address 0x", Compiler.bitArrayToHex(tmp.data, ceil(RAM_ADDR_SIZE / 4)), ".\n"
            );

            if HALT_ON_UNKNOWN {
                this.__quit();
            } else {
                IO.out(" Skipping address.\n");
                return;
            }
        } 
            
        $call clock
                
        this.__microcode[instruction]();

        if this.interruptRegister.data != [0 for _ in range(INTERRUPT_BITS)] and not this.__onInterrupt {
            new int interrupt = this.interruptRegister.toDec();
            if interrupt in this.interruptHandlers {
                this.__ps(this.getProgramCounter())();

                this.bus.load(this.interruptHandlers[interrupt]);
                this.getProgramCounter().load();

                this.__onInterrupt = True;
            } else {
                this.interruptRegister.reset();

                if UNHANDLED_INTERRUPT_ALERT {
                    IO.out("WARNING: Unhandled interrupt received.\n");
                }
            }
        }
    }

    new method __draw() {
        # fetch
        this.programCounter.write();
        this.mar.load();

        $call clock

        # save instruction
        this.ram.write();
        this.instructionRegister.load();

        # increment program counter
        this.programCounter.inc();

        this.__handleInstruction();
    }

    new method run() {
        this.graphics.run(handleQuit = False, drawBackground = False, autoUpdate = False);
    }
}

new function prettyPrintFreq(n) {
    if n >= 1000 {
        n /= 1000;

        if n >= 1000 {
            n /= 1000;

            return str(round(n, 4)) + " MHz";
        }

        return str(round(n, 4)) + " KHz";
    }

    return str(round(n, 4)) + " Hz";
}

new function getFloatArg(name, shName) {
    if name in argv {
        new int idx = argv.index(name);
        argv.pop(idx);

        new dynamic value = argv.pop(idx);

        try {
            value = float(value);
        } catch ValueError {
            IO.out(f"Invalid {shName} value given. Using default.\n");
        } success {
            return value;
        }
    }
}

main {
    if "--simple-audio" in argv {
        argv.remove("--simple-audio");
        SIMPLE_AUDIO = True;
    }

    if "--resolution" in argv {
        new int idx = argv.index("--resolution");
        argv.pop(idx);

        new list res = argv.pop(idx).lower().split("x");

        if len(res) != 2 {
            IO.out("Invalid resolution value given. Using default.\n");
        } else {
            new dynamic tmp = Vector().fromList(res);

            try {
                tmp = tmp.getIntCoords();
            } catch ValueError {
                IO.out("Invalid resolution value given. Using default.\n");
            } success {
                RESOLUTION = tmp;
            }
        }
    }

    new dynamic tmp = getFloatArg("--scale", "scale");

    if tmp is not None {
        SCREEN_SCALE = tmp;
    }

    dynamic: tmp = getFloatArg("--clock", "clock");

    if tmp is not None {
        CLOCK_PULSE_DURATION = tmp;
    }

    new <Computer> computer = Computer();
    new <Compiler> compiler = Compiler();

    new dynamic txt;
    with open(argv[1], "r") as txt {
        computer.ram.init(compiler.compile(txt.read()));
    }

    computer.sp.data = compiler.decimalToBitarray(compiler.stackPos);

    computer.interruptHandlers = compiler.interruptHandlers;
    computer.keyBufferAddr     = compiler.keyBufferAddr;
    computer.waitAddress       = compiler.waitAddress;
    computer.waitEnd           = compiler.waitEnd;

    IO.out("Timing clock...\n");
    new dynamic sTime = default_timer();
    $call clock
    sTime = default_timer() - sTime;

    IO.out(f"CPU clock is running at ~{prettyPrintFreq(1 / sTime)}.\n");

    if not compiler.hadError {
        IO.out(
            "Stack is located at address 0x", Compiler.bitArrayToHex(computer.sp.data, ceil(RAM_ADDR_SIZE / 4)), 
            " and has ", compiler.stackSize, f" words allocated ({compiler.stackSize * BITS / 8} bytes)\n"
        );

        if STACK_PROTECTION {
            computer.stackBase = compiler.stackPos;
            computer.stackTop  = compiler.stackPos + compiler.stackSize;

            IO.out("Stack protection is enabled.\n");
        }
    }

    IO.out("Key buffer is located at address 0x", hex(computer.keyBufferAddr)[2:].zfill(ceil(RAM_ADDR_SIZE / 4)), ".\n\n");

    mixer.set_num_channels(SOUND_CHANNELS);

    computer.run();
}