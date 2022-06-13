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

        this.variables = {};
        this.interruptHandlers = {};

        this.clockSpeed = DEFAULT_CLOCK_PULSE_DURATION;
        this.keyBufferAddr = 2 ** RAM_ADDR_SIZE - 1;

        this.result = [];

        this.INSTRUCTION_HANDLERS = {
            "nop": this.__np(0),
            "lix": this.__li(1),
            "liy": this.__li(2),
            "liz": this.__li(3),
            "lia": this.__li(4),
            "lib": this.__li(5),
            "lid": this.__li(6),
            "flx": this.__fl(7),
            "fly": this.__fl(8),
            "flz": this.__fl(9),
            "fla": this.__fl(10),
            "flb": this.__fl(11),
            "fld": this.__fl(12),
            "lox": this.__li(13),
            "loy": this.__li(14),
            "loz": this.__li(15),
            "loa": this.__li(16),
            "lob": this.__li(17),
            "lod": this.__li(18),
            "stx": this.__li(19),
            "sty": this.__li(20),
            "stz": this.__li(21),
            "sta": this.__li(22),
            "stb": this.__li(23),
            "std": this.__li(24),
            "add": this.__np(25),
            "sub": this.__np(26),
            "adi": this.__adsbi(27),
            "sbi": this.__adsbi(28),
            "dpm": this.__fl(29),
            "dlp": this.__np(30),
            "dli": this.__li(31),
            "fdl": this.__fl(32),
            "jmp": this.__li(33),
            "jmi": this.__fl(34),

            "jc" : this.__li(35),
            "jgt": this.__li(35),

            "jci": this.__fl(36),
            "jgi": this.__fl(36),

            "jz" : this.__li(37),
            "jeq": this.__li(37),

            "jzi": this.__fl(38),
            "jei": this.__fl(38),

            "inx": this.__np(39),
            "iny": this.__np(40),
            "inz": this.__np(41),
            "ina": this.__np(42),
            "inb": this.__np(43),
            "ind": this.__np(44),
            "dcx": this.__np(45),
            "dcy": this.__np(46),
            "dcz": this.__np(47),
            "dca": this.__np(48),
            "dcb": this.__np(49),
            "dcd": this.__np(50),
            "slx": this.__fl(51),
            "sly": this.__fl(52),
            "slz": this.__fl(53),
            "sla": this.__fl(54),
            "slb": this.__fl(55),
            "sld": this.__fl(56),
            "srx": this.__fl(57),
            "sry": this.__fl(58),
            "srz": this.__fl(59),
            "sra": this.__fl(60),
            "srb": this.__fl(61),
            "srd": this.__fl(62),
            "rlx": this.__fl(63),
            "rly": this.__fl(64),
            "rlz": this.__fl(65),
            "rla": this.__fl(66),
            "rlb": this.__fl(67),
            "rld": this.__fl(68),
            "rrx": this.__fl(69),
            "rry": this.__fl(70),
            "rrz": this.__fl(71),
            "rra": this.__fl(72),
            "rrb": this.__fl(73),
            "rrd": this.__fl(74),
            "mxy": this.__np(75),
            "mxz": this.__np(76),
            "mxa": this.__np(77),
            "mxb": this.__np(78),
            "mxd": this.__np(79),
            "myx": this.__np(80),
            "myz": this.__np(81),
            "mya": this.__np(82),
            "myb": this.__np(83),
            "myd": this.__np(84),
            "mzx": this.__np(85),
            "mzy": this.__np(86),
            "mza": this.__np(87),
            "mzb": this.__np(88),
            "mzd": this.__np(89),
            "max": this.__np(90),
            "may": this.__np(91),
            "maz": this.__np(92),
            "mab": this.__np(93),
            "mad": this.__np(94),
            "mbx": this.__np(95),
            "mby": this.__np(96),
            "mbz": this.__np(97),
            "mba": this.__np(98),
            "mbd": this.__np(99),
            "mdx": this.__np(100),
            "mdy": this.__np(101),
            "mdz": this.__np(102),
            "mda": this.__np(103),
            "mdb": this.__np(104),
            "lax": this.__np(105),
            "lay": this.__np(106),
            "laz": this.__np(107),
            "laa": this.__np(108),
            "lab": this.__np(109),
            "lad": this.__np(110),
            "cmp": this.__np(111),
            "cpi": this.__adsbi(112),
            "los": this.__li(113),
            "lis": this.__li(114),
            "sts": this.__li(115),
            "ins": this.__np(116),
            "dcs": this.__np(117),
            "psx": this.__np(118),
            "psy": this.__np(119),
            "psz": this.__np(120),
            "psa": this.__np(121),
            "psb": this.__np(122),
            "psd": this.__np(123),
            "ppx": this.__np(124),
            "ppy": this.__np(125),
            "ppz": this.__np(126),
            "ppa": this.__np(127),
            "ppb": this.__np(128),
            "ppd": this.__np(129),
            "jsr": this.__li(130),
            "rts": this.__np(131),
            "nex": this.__np(132),
            "ney": this.__np(133),
            "nez": this.__np(134),
            "nea": this.__np(135),
            "neb": this.__np(136),
            "ned": this.__np(137),
            "jod": this.__li(138),
            "jdi": this.__fl(139),
            "int": this.__fl(140),
            "rti": this.__np(141),
            "lgx": this.__li(142),
            "lgy": this.__li(143),
            "fgx": this.__li(144),
            "fgy": this.__li(145),
            "gpm": this.__fl(146),
            "fsx": this.__np(147),
            "fsy": this.__np(148),
            "fsz": this.__np(149),
            "fsa": this.__np(150),
            "fsb": this.__np(151),
            "fsd": this.__np(152),
            "gxx": this.__np(153),
            "gyy": this.__np(154),
            
            "hlt": this.__np(255)
        };
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

                this.oLine = this.getValue(line[charPtr:]);
                continue;
            } elif line.startswith(".fill") or line.startswith(".stack") {
                new dynamic charPtr, plh;
                unchecked:
                plh, charPtr = this.getUntilNotWord(line, 5);

                this.oLine += this.getValue(line[charPtr:]);
                continue;
            } elif line.startswith(".string") {
                this.oLine += len(eval(line[7:]));

                continue
            } elif line.startswith(".interrupt") {
                continue;
            } elif line.startswith(".clock") {
                this.clockSpeed = float(line[7:]);
                continue;
            } elif line.startswith(".keyBuffer") {
                this.keyBufferAddr = this.oLine;

                this.oLine++; 
                continue;
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

            if line.startswith(":") or line.startswith(".clock") or line.startswith(".keyBuffer") {
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