Engine_Autumn : CroneEngine {
  var pg;
  var amp = 0.3;
  var attack = 0.5;
  var release = 0.5;
  var pan = 0.0;
  var pw = 0.5;
  var cutoff = 1000;
  var gain = 1;
  var bits = 32;
  var hiss = 0;
  var sampleRate = 48000.0;
  var rustlepan = 0.5;
  var rustleamp = 0.0;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    pg = ParGroup.tail(context.xg);
    SynthDef("Autumn", {
      arg out, freq = 440, pw = pw, pan = pan, amp = amp, cutoff = cutoff, gain = gain, attack = attack, release = release, bits = bits, hiss = hiss;
      var snd = Pulse.ar(freq, pw);
      var filt = MoogFF.ar(snd, cutoff, gain);
      var env = Linen.kr(Impulse.kr(0), attack, amp, release, doneAction: Done.freeSelf);
      var panAr = Pan2.ar(filt * env, pan, 1.0);
      var decimate = Decimator.ar(panAr, rate: sampleRate, bits: bits, mul: 1.0, add: 0);
      var hissMix = HPF.ar(Mix.new([PinkNoise.ar(1), Dust.ar(5,1)]), 2000, 1);
      var duckedHiss = Compander.ar(hissMix, decimate,
        thresh: 0.4,
        slopeBelow: 1,
        slopeAbove: 0.2,
        clampTime: 0.01,
        relaxTime: 0.1,
      ) * (hiss / 500);
      Out.ar(out, Mix.new([decimate, duckedHiss]));
    }).add;

    SynthDef("Autumn-rustle", {
      arg out, rustlefreq = rustlefreq, rustlepan = rustlepan, rustleamp = rustleamp, gain = gain, attack = attack, release = release, bits = bits, hiss = hiss;
      var snd = BHiPass4.ar(Mix.new([PinkNoise.ar(1), Dust.ar(5, 1)]), rustlefreq, 0.95, rustleamp);
      var env = Linen.kr(Impulse.kr(0), 1.8, rustleamp, 1.2, doneAction: Done.freeSelf);
      var panAr = Pan2.ar(snd * env, rustlepan, 1.0);
      Out.ar(out, panAr);
    }).add;

    this.addCommand("hz", "f", { arg msg;
      var val = msg[1];
      Synth("Autumn",
        [
          \out, context.out_b,
          \freq, val,
          \pw, pw,
          \amp, amp,
          \cutoff, cutoff,
          \gain, gain,
          \attack, attack,
          \release, release,
          \pan, pan,
          \bits, bits,
          \hiss, hiss
        ],
        target: pg
      );
    });
    this.addCommand("rustle", "f", { arg msg;
      var val = msg[1];
      Synth("Autumn-rustle",
        [
          \out, context.out_b,
          \rustlefreq, val,
          \rustleamp, rustleamp,
          \cutoff, cutoff,
          \gain, gain,
          \attack, attack,
          \release, release,
          \rustlepan, rustlepan,
          \bits, bits,
          \hiss, hiss
        ],
        target: pg
      );
    });
    this.addCommand("rustlepan", "f", { arg msg;
      rustlepan = msg[1];
    });
    this.addCommand("rustleamp", "f", { arg msg;
      rustleamp = msg[1];
    });
    this.addCommand("hiss", "i", { arg msg;
      hiss = msg[1];
    });
    this.addCommand("bits", "i", { arg msg;
      bits = msg[1];
    });
    this.addCommand("pan", "f", { arg msg;
      pan = msg[1];
    });
    this.addCommand("amp", "f", { arg msg;
      amp = msg[1];
    });
    this.addCommand("pw", "f", { arg msg;
      pw = msg[1];
    });
    this.addCommand("attack", "f", { arg msg;
      attack = msg[1];
    });
    this.addCommand("release", "f", { arg msg;
      release = msg[1];
    });
    this.addCommand("cutoff", "f", { arg msg;
      cutoff = msg[1];
    });
    this.addCommand("gain", "f", { arg msg;
      gain = msg[1];
    });
  }
}