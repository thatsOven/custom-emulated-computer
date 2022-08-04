package opal:   import *;
package time:   import sleep;
package sys:    import argv;
package math:   import ceil;
package timeit: import default_timer;
package pygame: import Surface, transform, draw;
import numpy;

new <Vector> RESOLUTION = Vector(256, 256);

new int BITS                = 16,
        RAM_ADDR_SIZE       = 20,
        SCREEN_MODE_BITS    = 2,
        FLAGS_QTY           = 3,
        INSTRUCTION_BITS    = 8,
        INTERRUPT_BITS      = 4,
        GPU_MODE_BITS       = 2,
        COLOR_BITS          = 5,
        GPU_MODIFIER_BITS   = 1,
        CHAR_BITS           = 7,
        CHAR_COLOR_BITS     = 2,
        CHAR_BG_COLOR_BITS  = 1,
        SOUND_FREQ_BITS     = 13,
        MAX_VOL_MULT        = 500,
        FREQUENCY_SAMPLE    = 30000;

new float DEFAULT_CLOCK_PULSE_DURATION = 0.01,
          SCREEN_SCALE                 = 1;

new bool HEX_DUMP                  = False,
         STACK_PROTECTION          = True,
         NOP_ALERT                 = True,
         UNKNOWN_OPCODE_ALERT      = True,
         HALT_ON_UNKNOWN           = True,
         UNHANDLED_INTERRUPT_ALERT = False,
         PERFORMANCE_AUDIO         = False;

new dynamic audio, audioMlt;
if PERFORMANCE_AUDIO {
    audio = numpy.sin;
    audioMlt = 10;
} else {
    package scipy: import signal;
    audio = signal.square;
    audioMlt = 1;
}

$macro clockExt
    sleep(this.computer.clockSpeed);
$end

$include os.path.join("HOME_DIR", "Compiler.opal")
$include os.path.join("HOME_DIR", "components.opal")

new class Computer {
    $macro clock
        sleep(this.clockSpeed);
    $end
    
    $include os.path.join("HOME_DIR", "microcodeMethods.opal")

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

        this.clockSpeed    = DEFAULT_CLOCK_PULSE_DURATION;
        this.keyBufferAddr = 2 ** RAM_ADDR_SIZE - 1;

        $include os.path.join("HOME_DIR", "CPUMicrocode.opal")
    }

    new method __setSample(dur) {
        this.soundSample = numpy.arange(0, dur, 1 / this.graphics.frequencySample);
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

        new int instruction = this.instructionRegister.instruction.toDec();

        # 255 = HLT
        if instruction == 255 or this.stackError {
            this.__quit();
        } elif instruction == 254 {
            this.graphics.restore();
            return;
        } elif instruction == 253 {
            this.graphics.loopOnly();
            return;
        } elif instruction >= len(this.__microcode) and UNKNOWN_OPCODE_ALERT {
            new <Register> tmp = Register(None, RAM_ADDR_SIZE, False);
            tmp.data = this.programCounter.data.copy();
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
                this.__ps(this.programCounter)();

                this.bus.load(this.interruptHandlers[interrupt]);
                this.programCounter.load();

                this.__onInterrupt = True;
            } elif UNHANDLED_INTERRUPT_ALERT {
                this.interruptRegister.reset();
                IO.out("WARNING: Unhandled interrupt received.\n");
            }
        }

        if not this.graphics.stopped {
            transform.scale(this.gpu.frameBuffer, (this.screenSize.x, this.screenSize.y), this.graphics.screen);
        }
    }

    new method run() {
        this.graphics.run(handleQuit = False);
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

main {
    new <Computer> computer = Computer();
    new <Compiler> compiler = Compiler();

    new dynamic txt;
    with open(argv[1], "r") as txt {
        computer.ram.init(compiler.compile(txt.read()));
    }

    computer.sp.data = compiler.decimalToBitarray(compiler.stackPos);

    computer.interruptHandlers = compiler.interruptHandlers;
    computer.clockSpeed        = compiler.clockSpeed;
    computer.keyBufferAddr     = compiler.keyBufferAddr;

    IO.out("Timing clock...\n");
    new dynamic sTime = default_timer();
    sleep(computer.clockSpeed);
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

    computer.run();
}