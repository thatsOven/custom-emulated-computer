new class SoundChip : Component {
    new int MAX_SAWTOOTH_AMP   = 2 ** SAWTOOTH_AMP_BITS - 1,
            MAX_SQUARE_AMP     = 2 ** SQUARE_AMP_BITS - 1,
            SAWTOOTH_WIDTH_DEN = 2 ** SAWTOOTH_WIDTH_BITS - 1,
            SQUARE_PWM_DEN     = 2 ** SQUARE_PWM_WIDTH_BITS - 1;

    new method __init__(computer) {
        super().__init__(computer);

        this.frequency = Register(this.computer, SOUND_FREQ_BITS, False);
        this.amplitude = Register(this.computer, BITS - SOUND_FREQ_BITS, False);
        this.mixer     = Register(this.computer, BITS, False);
        this.duration  = Register(this.computer, BITS, False);
    }

    new method load() {
        new <Register> tmp = Register(this.computer, BITS, False);
        tmp.load();

        $call clock

        tmp.write();
        this.computer.mar.load();

        $call clock

        this.computer.ram.write();

        # get frequency and amplitude of wave
        for i = 0; i < len(this.frequency.data); i++ {
            this.frequency.data[i] = this.computer.bus.data[i];
        }

        for j = 0; i < BITS; i++, j++ {
            this.amplitude.data[j] = this.computer.bus.data[i];
        }

        $call clock

        this.computer.mar.inc();

        $call clock
        
        if not SIMPLE_AUDIO {
            # get mixer data
            this.computer.ram.write();
            this.mixer.load();

            $call clock

            this.computer.mar.inc();

            $call clock
        }
        
        # get sound duration
        this.computer.ram.write();
        this.duration.load();
    }

    new method getMixedWave(baseArray) {
        if SIMPLE_AUDIO {
            return signal.square(baseArray);
        }

        new dynamic squareAmp, squarePWM, sawtoothAmp, sawtoothWidth;
        squareAmp     = Register(None,       SQUARE_AMP_BITS, False);
        squarePWM     = Register(None, SQUARE_PWM_WIDTH_BITS, False);
        sawtoothAmp   = Register(None,     SAWTOOTH_AMP_BITS, False);
        sawtoothWidth = Register(None,   SAWTOOTH_WIDTH_BITS, False);

        new int p0 = SQUARE_AMP_BITS + SQUARE_PWM_WIDTH_BITS,
                p1 = p0 + SAWTOOTH_AMP_BITS,
                p2 = p1 + SAWTOOTH_WIDTH_BITS;

        squareAmp.data     = this.mixer.data[:SQUARE_AMP_BITS];
        squarePWM.data     = this.mixer.data[SQUARE_AMP_BITS:p0];
        sawtoothAmp.data   = this.mixer.data[p0:p1];
        sawtoothWidth.data = this.mixer.data[p1:p2];

        if squarePWM.toDec() == 0 {
            return ((  squareAmp.toDec() /   SoundChip.MAX_SQUARE_AMP) * signal.square(baseArray)) +
                   ((sawtoothAmp.toDec() / SoundChip.MAX_SAWTOOTH_AMP) * SAWTOOTH_MULT * signal.sawtooth(baseArray, sawtoothWidth.toDec() / SoundChip.SAWTOOTH_WIDTH_DEN)); 
        } else {
            return ((  squareAmp.toDec() /   SoundChip.MAX_SQUARE_AMP) * signal.square(baseArray, signal.sawtooth(baseArray, squarePWM.toDec() / SoundChip.SQUARE_PWM_DEN))) +
                   ((sawtoothAmp.toDec() / SoundChip.MAX_SAWTOOTH_AMP) * SAWTOOTH_MULT * signal.sawtooth(baseArray, sawtoothWidth.toDec() / SoundChip.SAWTOOTH_WIDTH_DEN)); 
        }
    }

    new method play() {
        new dynamic amp, freq, tmp, sample;
        amp = Utils.translate(this.amplitude.toDec(), 0, len(this.amplitude.data), 0, MAX_VOL_MULT);
        freq = this.frequency.toDec();

        if amp == 0 {
            return;
        }

        sample = numpy.arange(0, this.duration.toDec() / 1000, 1 / this.computer.graphics.frequencySample);
        tmp = amp * this.getMixedWave(2 * numpy.pi * freq * sample);

        if this.computer.audioChs > 1 {
            this.computer.graphics.playWaveforms([numpy.repeat(tmp.reshape(tmp.size, 1), this.computer.audioChs, axis = 1)]);
        } else {
            this.computer.graphics.playWaveforms([tmp]);
        }
    }
}