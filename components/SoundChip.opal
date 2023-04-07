new class SoundChip : Component {
    new int MAX_SAWTOOTH_AMP   = 2 ** SAWTOOTH_AMP_BITS - 1,
            MAX_SQUARE_AMP     = 2 ** SQUARE_AMP_BITS - 1,
            SAWTOOTH_WIDTH_DEN = 2 ** SAWTOOTH_WIDTH_BITS - 1,
            SQUARE_PWM_DEN     = 2 ** SQUARE_PWM_WIDTH_BITS - 1,
            MAX_ND_SQUARE_AMP  = 2 ** ND_SQUARE_AMP_BITS - 1,
            SQUARE_DUTY_DEN    = 2 ** SQUARE_DUTY_BITS - 1,
            MAX_NOISE_AMP      = 2 ** NOISE_AMP_BITS - 1,
            MAX_AMP            = 2 ** (BITS - SOUND_FREQ_BITS) - 1;

    new method __init__(computer) {
        super().__init__(computer);

        this.frequency = Register(this.computer, SOUND_FREQ_BITS, False);
        this.amplitude = Register(this.computer, BITS - SOUND_FREQ_BITS, False);
        this.mixerSt   = Register(this.computer, BITS, False);
        this.mixerNd   = Register(this.computer, BITS, False);
        this.duration  = Register(this.computer, BITS, False);
    }

    new method load() {
        new Register tmp = Register(this.computer, BITS, False);
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
        
        if MIXER_WORDS > 0 {
            # get mixer data
            this.computer.ram.write();
            this.mixerSt.load();

            $call clock

            this.computer.mar.inc();

            $call clock
        }

        if MIXER_WORDS == 2 {
            # get mixer data
            this.computer.ram.write();
            this.mixerNd.load();

            $call clock

            this.computer.mar.inc();

            $call clock
        }
        
        # get sound duration
        this.computer.ram.write();
        this.duration.load();
    }

    new method getMixedWave(baseArray) {
        if MIXER_WORDS == 0 {
            return signal.square(baseArray);
        }

        new dynamic squareAmp, squarePWM, sawtoothAmp, sawtoothWidth, tmp;
        squareAmp     = Register(None,       SQUARE_AMP_BITS, False);
        squarePWM     = Register(None, SQUARE_PWM_WIDTH_BITS, False);
        sawtoothAmp   = Register(None,     SAWTOOTH_AMP_BITS, False);
        sawtoothWidth = Register(None,   SAWTOOTH_WIDTH_BITS, False);

        new int p0 = SQUARE_AMP_BITS + SQUARE_PWM_WIDTH_BITS,
                p1 = p0 + SAWTOOTH_AMP_BITS,
                p2 = p1 + SAWTOOTH_WIDTH_BITS;

        squareAmp.data     = this.mixerSt.data[:SQUARE_AMP_BITS];
        squarePWM.data     = this.mixerSt.data[SQUARE_AMP_BITS:p0];
        sawtoothAmp.data   = this.mixerSt.data[p0:p1];
        sawtoothWidth.data = this.mixerSt.data[p1:p2];

        if squarePWM.toDec() == 0 {
            tmp = ((  squareAmp.toDec() /   SoundChip.MAX_SQUARE_AMP) * signal.square(baseArray)) +
                  ((sawtoothAmp.toDec() / SoundChip.MAX_SAWTOOTH_AMP) * signal.sawtooth(baseArray, sawtoothWidth.toDec() / SoundChip.SAWTOOTH_WIDTH_DEN)); 
        } else {
            tmp = ((  squareAmp.toDec() /   SoundChip.MAX_SQUARE_AMP) * signal.square(baseArray, signal.sawtooth(baseArray, squarePWM.toDec() / SoundChip.SQUARE_PWM_DEN))) +
                  ((sawtoothAmp.toDec() / SoundChip.MAX_SAWTOOTH_AMP) * signal.sawtooth(baseArray, sawtoothWidth.toDec() / SoundChip.SAWTOOTH_WIDTH_DEN)); 
        }

        if MIXER_WORDS == 2 {
            new dynamic ndSquareAmp, squareDuty, noiseAmp;
            ndSquareAmp = Register(None, ND_SQUARE_AMP_BITS, False);
            squareDuty  = Register(None,   SQUARE_DUTY_BITS, False);
            noiseAmp    = Register(None,     NOISE_AMP_BITS, False);

            p0 = ND_SQUARE_AMP_BITS + SQUARE_DUTY_BITS;
            p1 = p0 + NOISE_AMP_BITS;
                
            ndSquareAmp.data = this.mixerNd.data[:ND_SQUARE_AMP_BITS];
            squareDuty.data  = this.mixerNd.data[ND_SQUARE_AMP_BITS:p0];
            noiseAmp.data    = this.mixerNd.data[p0:p1];

            return tmp + ((ndSquareAmp.toDec() / SoundChip.MAX_ND_SQUARE_AMP) * signal.square(baseArray, squareDuty.toDec() / SoundChip.SQUARE_DUTY_DEN)) + 
                         ((   noiseAmp.toDec() /     SoundChip.MAX_NOISE_AMP) * numpy.random.uniform(-1, 1, len(baseArray)));
        } else {
            return tmp;
        }
    }

    new method play() {
        new dynamic tmp, sample;
        new float amp = Utils.translate(this.amplitude.toDec(), 0, SoundChip.MAX_AMP, 0, MAX_VOL_MULT);
        new int freq = this.frequency.toDec();

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