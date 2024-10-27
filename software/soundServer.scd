// soundServer.scd

// server settings and synthDefs, run this ___

(
o = Server.default.options;
o.numInputBusChannels = 4;
o.numOutputBusChannels = 6; // four for the quartet (0, 1, 2, 3) and two for the house (4, 5)
o.sampleRate_(48000);

ServerOptions.devices;
// use this for testing
//o.inDevice_("BlackHole 64ch");
//o.outDevice_("BlackHole 64ch");

//o.inDevice_("MacBook Pro Microphone");
//o.outDevice_("MacBook Pro Speakers");

// use this for performance with evo 16
o.inDevice_("Audient EVO16");
o.outDevice_("Audient EVO16");

s.waitForBoot( { // boot server
	// ADD SYNTHS TO SERVER
	s.freeAll;

	// 1. live mic input
	SynthDef.new( \micLive, {
		arg in=0, inputGain=1.0, out=0;
		var sig;
		sig = SoundIn.ar(in, inputGain);
		// add EQ
		sig = LPF.ar(sig, 1500.0, 0.7);
		sig = HPF.ar(sig, 50.0, 0.7);
		// add limiter
		sig = Limiter.ar(sig, 0.8, 0.01); // this works but need to finesse
		out = Out.ar(out, sig);
	}).add;

	// 2. mic sampler
	SynthDef.new( \micSampler, {
		arg in=0, inputGain=1.0, out=0;
		var sig;
		sig = SoundIn.ar(in, inputGain);
		out = Out.ar(out, sig); // this will be specified as a Bus when it's in use
	}).add;

	// 3. sine bank
	SynthDef.new( \sinBank_x, {
		arg out=0, gate;
		var size=~numSines, env, sig, freqs, amps, phases;

		// initialize freq, amp, phase data
		freqs = Array.fill(size, {440} );
		amps = Array.fill(size, { 1/size } );
		phases = Array.fill(size, { arg i; i.mod(2pi) } );

		// amp envelope = attack, sustain, release
		env = EnvGen.kr(Env.asr(0.5, 1.0, \release.kr(0.1) ), gate );

		// signal
		sig = DynKlang.ar ( `[ \freqs.kr(freqs).lag(0.01), \amps.kr(amps), \phases.kr(phases) ] );
		sig = sig * env;
		Out.ar(out, sig);
	}).add;

	// 4. FR playback

	SynthDef.new(\bufPlay_mono, {
		// playback synth for single channel
		arg buf=0, rate=1, startPos=0, t_trig=1, loop=0, da=0, amp=1.0, pan=0, out=0, gate=0;
		var numChannels, env, sig;

		// mono
		numChannels = 1;

		// amp envelope = attack, sustain, release
		env = EnvGen.kr( Env.asr(0.01, 1.0, 0.01), gate );

		sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, t_trig, startPos, loop, da);
		sig = sig * amp * env;

		Out.ar(out, sig);
	}).add;






/*
// build bufPlay synths
fork{ 1.0.wait;
	bufPlayers = bufs.collect( {
		arg buf;
		Synth.new(\bufPlay, [
			\buf, buf.bufnum,
			\t_trig, 0,
			\loop, 1,
		])
	});
};
	*/
	// 5. salemCov FR playback

	// 6. piano notes playback

	s.sync;

	// allocate buses and instances of mic synths and sine banks
	~micSamplerBuses = Array.fill(~numInputs, { Bus.audio(s, 1) } );
	// assign micSampler synths to micSamplerBuses
	~micSamplerSynths = Array.fill(~numInputs, { arg i; Synth.new(\micSampler, [\in, i, \out, ~micSamplerBuses[i] ] ) } );
	// micLive synths to analog outputs
	~micLiveSynths = Array.fill(~numInputs, { arg i; Synth.new(\micLive, [\in, i, \inputGain, 0.6, \out, i] ) } );
	// sinBank synths to analog outputs
	~sinSynths = Array.fill(~numInputs, { arg i; Synth.new(\sinBank_x, [\out, i] ) } );

	s.sync;

	// build audio buffers
	Buffer.freeAll; // free anything that's already allocated

	~pianoLeftBufs = ~readInBufs.(~pianoNotesLeftDir);
	~pianoRightBufs = ~readInBufs.(~pianoNotesRightDir);

	~pianoLeftPlayers = Array.fill(2, { arg i; Synth.new(\bufPlay_mono, [\out, i]) } ); // this will get set to outputs 0 and 1
	~pianoRightPlayers = Array.fill(2, { arg i; Synth.new(\bufPlay_mono, [\out, i]) } ); // this will get set to outputs 2 and 3 (i+2)

	/*Routine.new( {
		~pianoLeftBufs = ~pianoNotesLeftDir.entries.collect( {
			arg fn;
			Buffer.read(s, fn.fullPath);
		});
	}).play;
*/
	s.sync;

	~pianoLeftPlayers[[0,1].choose].set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
	~pianoRightPlayers[[0,1].choose].set(\buf, ~pianoRightBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
});

s.meter;

)

//~sinSynths[0].set(\gate, 0);
//~micLiveSynths[0].set(\inputGain, 1);
//~pianoLeftPlayers[[0,1].choose].set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
//~pianoRightPlayers[[0,1].choose].set(\buf, ~pianoRightBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);

//x = Synth.new(\bufPlay_mono, ~pianoLeftBufs[0]);
//x.set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
//x.set(\gate, 1);
//~pianoLeftBufs.choose;