new class GPU : Component {
    new method __init__(computer, resolution) {
        super().__init__(computer);

        this.x = Register(computer, BITS, False);
        this.y = Register(computer, BITS, False);

        this.frameBuffer = Surface((resolution.x, resolution.y));

        this.mode = Register(computer, GPU_MODE_BITS, False);

        $include os.path.join(HOME_DIR, "baseComponents", "characterROM.opal")
    }

    new method __getColor(data) {
        new int prc0 = COLOR_BITS * 2,
                prc1 = prc0 + COLOR_BITS,
                prc2 = prc1 + GPU_MODIFIER_BITS;

        new dynamic blue  = data.data[:COLOR_BITS],
                    green = data.data[COLOR_BITS:prc0],
                    red   = data.data[prc0:prc1],
                    modif = data.data[prc1:prc2];

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

        $call clock

        this.computer.ram.write();
        new dynamic w = Register(this.computer, BITS, False);
        w.load();

        $call clock

        this.computer.mar.inc();

        $call clock

        this.computer.ram.write();
        new dynamic h = Register(this.computer, BITS, False);
        h.load();

        $call clock

        this.computer.mar.inc();

        $call clock

        this.computer.ram.write();
        new dynamic c = Register(this.computer, BITS, False);
        c.load();
        c = this.__getColor(c);

        return w.toDec(), h.toDec(), c;
    }

    new method load() {
        match this.mode.data {
            # pixel mode
            case [0, 0, 0] {
                new <Register> tmp = Register(this.computer, BITS, False);
                tmp.load();

                this.frameBuffer.set_at((this.x.toDec(), this.y.toDec()), this.__getColor(tmp));
            } 
            # text mode
            case [1, 0, 0] {
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
            # rect mode
            case [0, 1, 0] {
                new dynamic w, h, c;
                unchecked: w, h, c = this.__get3Data();

                draw.rect(this.frameBuffer, c, (this.x.toDec(), this.y.toDec(), w, h));
            }
            # line mode
            case [1, 1, 0] {
                new dynamic dstX, dstY, c;
                unchecked: dstX, dstY, c = this.__get3Data();

                draw.line(this.frameBuffer, c, (this.x.toDec(), this.y.toDec()), (dstX, dstY));
            }
            # b/w mode
            case [0, 0, 1] {
                new dynamic resolution = this.frameBuffer.get_size();
                new <Register> tmp = Register(this.computer, BITS, False);
                tmp.load();

                new dynamic x = this.x.toDec(),
                            y = this.y.toDec();

                for i = 0; i < BITS; i++, x++ {
                    this.frameBuffer.set_at((x, y), (255, 255, 255) if tmp.bits[i] else (0, 0, 0));

                    if x == resolution[0] {
                        x = 0;
                        y++;
                    }
                }
            }
        }

        if not this.computer.graphics.stopped {
            transform.scale(this.frameBuffer, (this.computer.screenSize.x, this.computer.screenSize.y), this.computer.graphics.screen);
            this.computer.graphics.rawUpdate();
        }
    }
}