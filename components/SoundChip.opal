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
        tmp = amp * signal.square(2 * numpy.pi * freq * sample);

        if this.computer.audioChs > 1 {
            this.computer.graphics.playWaveforms([numpy.repeat(tmp.reshape(tmp.size, 1), this.computer.audioChs, axis = 1)]);
        } else {
            this.computer.graphics.playWaveforms([tmp]);
        }
    }
}