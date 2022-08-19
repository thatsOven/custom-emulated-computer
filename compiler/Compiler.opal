new class Compiler {
    new classmethod fill(bits, amt = BITS) {
        return bits + [0 for _ in range(amt - len(bits))];
    }

    new classmethod decimalToBitarray(n) {
        if n < 0 {
            new list val = list(reversed([int(x) for x in bin(-int(n))[2:]]));
            new <Register> tmp;
            tmp = Register(None, len(val), False);
            tmp.data = val;
            tmp.invert();
            tmp.inc();

            return tmp.data;
        }

        return list(reversed([int(x) for x in bin(int(n))[2:]]));
    }

    new classmethod bitArrayToHex(n, fill) {
        return hex(int("".join([str(x) for x in reversed(n)]), 2))[2:].zfill(fill);
    }

    new method getUntil(section, ch, charPtr) {
        new str content = "";

        while section[charPtr] != ch or (section[charPtr - 1] == "\\" and section[charPtr] == ch) {
            if section[charPtr - 1] == "\\" and section[charPtr] == ch {
                content = content[:-1];
            }

            content += section[charPtr];
            charPtr++;

            if charPtr >= len(section) {
                charPtr = len(section) - 2;
                this.__error('expecting character "' + ch + '"');
                break;
            }
        }

        return content, charPtr + 1;
    }

    new method getValue(section) {
        if this.fetching {
            return 0;
        }

        new str noSpaceSec = section.replace(" ", "");

        if noSpaceSec == "" {
            return 0;
        } elif noSpaceSec in this.variables {
            return this.variables[noSpaceSec];
        } elif "+" in noSpaceSec or "-" in noSpaceSec {
            new list args;
            if "+" in noSpaceSec {
                args = section.split("+", maxsplit = 1);
                return this.getValue(args[0]) + this.getValue(args[1]);
            } else {
                args = section.split("-", maxsplit = 1);
                return this.getValue(args[0]) - this.getValue(args[1]);
            }
        } elif noSpaceSec.startswith("0x") {
            return int(noSpaceSec[2:], 16);
        } elif noSpaceSec.startswith("'") {
            new dynamic content, charPtr;

            unchecked:
            content, charPtr = this.getUntil(section, "'", 0);

            unchecked:
            content, charPtr = this.getUntil(section, "'", charPtr);

            content = eval('"' + content + '"');

            if len(content) > 1 {
                this.__error("more than one character included in character expression");
                return 0;
            }

            return ord(content);
        }
        
        return int(section);
    }

    new method __np(instr) {
        instr = this.decimalToBitarray(instr);

        new function np(line) {
            return [this.fill([], BITS - INSTRUCTION_BITS) + 
                    this.fill(instr, INSTRUCTION_BITS)];
        }
        
        return np;
    }

    new method __li(instr) {
        instr = this.decimalToBitarray(instr);

        new function li(line) {
            return [this.fill([], BITS - INSTRUCTION_BITS) + 
                    this.fill(instr, INSTRUCTION_BITS), 
                    this.fill(this.decimalToBitarray(this.getValue(line)))];
        }

        return li;
    }

    new method __fl(instr) {
        instr = this.decimalToBitarray(instr);

        new function fl(line) {
            return [this.fill(this.decimalToBitarray(this.getValue(line)), BITS - INSTRUCTION_BITS) + 
                    this.fill(instr, INSTRUCTION_BITS)];
        }

        return fl;
    }

    new method __adsbi(instr) {
        instr = this.decimalToBitarray(instr);

        new function adsbi(line) {
            new dynamic vals;
            if this.fetching {
                vals = [0, 0];
            } else {
                vals = line.split(",");
            }
            
            return [this.fill([], BITS - INSTRUCTION_BITS) + 
                    this.fill(instr, INSTRUCTION_BITS), 
                    this.fill(this.decimalToBitarray(this.getValue(vals[0]))),
                    this.fill(this.decimalToBitarray(this.getValue(vals[1])))];
        }
        
        return adsbi;
    }

    new method __init__() {
        this.iLine = 1;
        this.oLine = 0;

        this.hadError = False;
        this.fetching = True;

        this.stackPos  = 0;
        this.stackSize = 0;

        this.waitAddress = None;
        this.waitEnd     = None;

        this.variables = {};
        this.interruptHandlers = {};

        this.keyBufferAddr = 2 ** RAM_ADDR_SIZE - 1;

        this.result = [];

        $include os.path.join("HOME_DIR", "compiler", "compilerInstructionHandlers.opal")
    }

    new method __error(msg) {
        this.hadError = True;

        IO.out(f"error (line {this.iLine}): ", msg, "\n");
    }

    new method getUntilNotWord(section, charPtr) {
        new str content = "";

        while section[charPtr].isalpha() {
            content += section[charPtr];
            charPtr++;

            if charPtr >= len(section) {
                charPtr = len(section) - 1;
                break;
            }
        }

        return content, charPtr + 1;
    }

    new method compile(code) {
        IO.out("Compiling...\n");

        # fetch labels
        for line in code.split("\n") {
            line = line.strip().replace("\t", "");

            if line.replace(" ", "").replace("\n", "") == "" {
                continue;
            }

            if line[0] == "#" {
                continue;
            }

            if line.startswith(":") {
                new dynamic name;
                unchecked:
                name, _ = this.getUntilNotWord(line, 1);

                this.variables[name] = this.oLine;

                continue;
            } elif line[0].isdigit() or line.startswith("'") or line.startswith("-") {
                this.oLine++; 

                continue;
            } elif line.startswith(".addr") {
                new dynamic charPtr, plh;
                unchecked:
                plh, charPtr = this.getUntilNotWord(line, 5);

                this.fetching = False;
                this.oLine = this.getValue(line[charPtr:]);
                this.fetching = True;
                continue;
            } elif line.startswith(".fill") or line.startswith(".stack") {
                new dynamic charPtr, plh;
                unchecked:
                plh, charPtr = this.getUntilNotWord(line, 5);

                this.fetching = False;
                this.oLine += this.getValue(line[charPtr:]);
                this.fetching = True;
                continue;
            } elif line.startswith(".string") {
                this.oLine += len(eval(line[7:]));

                continue
            } elif line.startswith(".interrupt") or line.startswith(".endwaiting") {
                continue;
            } elif line.startswith(".keyBuffer") {
                this.keyBufferAddr = this.oLine;

                this.oLine++; 
                continue;
            } elif line.startswith(".waiting") {
                this.oLine += 8;
            }

            new dynamic instruction, charPtr;
            unchecked:
            instruction, charPtr = this.getUntilNotWord(line, 0);
            instruction = instruction.lower();

            if instruction in this.INSTRUCTION_HANDLERS {                
                this.oLine += len(this.INSTRUCTION_HANDLERS[instruction](""));
            }
        }

        if this.hadError {
            IO.out(f"Compilation was not successful. 1 word (HLT instruction) written to RAM ({BITS / 8} bytes)\n");
            return this.INSTRUCTION_HANDLERS["hlt"]("");
        }

        this.oLine = 0;
        this.fetching = False;

        # compile
        for line in code.split("\n") {
            line = line.strip().replace("\t", "");

            if line.replace(" ", "").replace("\n", "") == "" {
                this.iLine++;
                continue;
            }

            if line[0] == "#" {
                this.iLine++;
                continue;
            }

            if line.startswith(":") or line.startswith(".keyBuffer") {
                this.iLine++;
                continue;
            } elif line[0].isdigit() or line.startswith("'") or line.startswith("-") {
                this.result += [this.fill(this.decimalToBitarray(this.getValue(line)))];
                this.oLine++; 

                this.iLine++;
                continue;
            } elif line.startswith(".addr") {
                new dynamic charPtr, plh;
                unchecked:
                plh, charPtr = this.getUntilNotWord(line, 1);

                new int val = this.getValue(line[charPtr:]);
                this.result += [this.fill([]) for _ in range(val - this.oLine)];
                this.oLine  = val;

                this.iLine++;
                continue;
            } elif line.startswith(".fill") or (stack := line.startswith(".stack")) {
                new dynamic charPtr, plh;
                unchecked:
                plh, charPtr = this.getUntilNotWord(line, 1);

                new int val = this.getValue(line[charPtr:]);
                this.result += [this.fill([]) for _ in range(val)];

                if stack {
                    this.stackPos  = this.oLine;
                    this.stackSize = val;
                }

                this.oLine  += val;

                this.iLine++;
                continue;
            } elif line.startswith(".string") {
                new str val  = eval(line[7:]);
                this.result += [this.fill(this.decimalToBitarray(ord(ch))) for ch in val];
                this.oLine  += len(val);

                this.iLine++;
                continue;
            } elif line.startswith(".interrupt") {
                this.interruptHandlers[this.getValue(line[11:])] = this.decimalToBitarray(this.oLine);

                this.iLine++;
                continue;
            } elif line.startswith(".waiting") {
                this.waitAddress = this.oLine;

                this.result += [this.fill(this.decimalToBitarray(this.oLine + 8))];
                this.result += [this.fill([]) for _ in range(7)];

                this.oLine += 8;
                
                this.iLine++;
                continue;
            } elif line.startswith(".endwaiting") {
                this.waitEnd = this.oLine;

                this.iLine++;
                continue;
            }

            new dynamic instruction, charPtr;
            unchecked:
            instruction, charPtr = this.getUntilNotWord(line, 0);
            instruction = instruction.lower();

            if instruction in this.INSTRUCTION_HANDLERS {
                new str passing;
                if charPtr == len(line) {
                    passing = "";
                } else {
                    passing = line[charPtr:];
                }
                
                new list tmp = this.INSTRUCTION_HANDLERS[instruction](passing);
                this.result += tmp;

                this.oLine += len(tmp);
            } else {
                this.__error('unknown instruction "' + instruction + '"');
            }

            this.iLine++;
        }
        
        if this.hadError {
            IO.out(f"Compilation was not successful. 1 word (HLT instruction) written to RAM ({BITS / 8} bytes)\n");
            return this.INSTRUCTION_HANDLERS["hlt"]("");
        } else {
            new int size = len(this.result);
            IO.out(f"Compilation was successful. Writing {size} words ({size * BITS / 8} bytes) to RAM...\n");

            if HEX_DUMP {
                IO.out("Machine code:\n");
                
                new int i = 0;
                for word in this.result {
                    IO.out(
                        hex(i)[2:].zfill(RAM_ADDR_SIZE // 4), ": ", 
                        this.bitArrayToHex(word[-INSTRUCTION_BITS:], ceil(INSTRUCTION_BITS / 4)), " ", 
                        this.bitArrayToHex(word[:-INSTRUCTION_BITS], ceil((BITS - INSTRUCTION_BITS) / 4)), IO.endl
                    );

                    i++;
                }
            }

            return this.result;
        }
    }
}