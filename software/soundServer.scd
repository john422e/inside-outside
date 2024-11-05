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
		arg in=0, inputGain=0.6, limiter = 0.3, amp = 1, out=0; // 0.6 is a good max for now
		var sig;
		sig = SoundIn.ar(in, inputGain);
		// add EQ
		sig = LPF.ar(sig, 1500.0, 0.7);
		sig = HPF.ar(sig, 50.0, 0.7);
		// add limiter
		sig = Limiter.ar(sig, limiter, 0.01) * amp; // this works but need to finesse?
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
		var size=~numSines, env, release, sig, freqs, amps, phases;

		release = 0.1;

		// initialize freq, amp, phase data
		freqs = Array.fill(size, {440} );
		amps = Array.fill(size, { 1/size } );
		phases = Array.fill(size, { arg i; i.mod(2pi) } );

		// amp envelope = attack, sustain, release
		env = EnvGen.kr(Env.asr(0.5, 1.0, release ), gate );

		// signal
		sig = DynKlang.ar ( `[ \freqs.kr(freqs).lag(0.01), \amps.kr(amps), \phases.kr(phases) ] );
		sig = sig * env;
		Out.ar(out, sig);
	}).add;

	// 4. FR playback

	SynthDef.new(\bufPlay_mono, {
		// playback synth for single channel
		arg buf=0, rate=1, startPos=0, t_trig=1, loop=0, da=0, amp=0.7, pan=0, out=0, gate=0;
		var numChannels, env, sig;

		// mono
		numChannels = 1;

		// amp envelope = attack, sustain, release
		env = EnvGen.kr( Env.asr(0.01, 1.0, 0.01), gate );

		sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, t_trig, startPos, loop, da);
		sig = sig * amp * env;

		Out.ar(out, sig);
	}).add;

	SynthDef.new(\bufPlay_stereo, {
		// playback synth for stereo
		arg buf=0, rate=1, startPos=0, t_trig=1, attack=0.01, loop=0, da=0, amp=1.0, pan=0, out=0, gate=0;
		var numChannels, env, sig;

		// stereo
		numChannels = 2;

		// amp envelope = attack, sustain, release
		env = EnvGen.kr( Env.asr(attack, 1.0, 0.01), gate );

		sig = PlayBuf.ar(2, buf, BufRateScale.ir(buf) * rate, t_trig, startPos, loop, da);
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


// ----------------------------------------------------------------------------

	// build arrays for filenames (in data.scd) and recorders
	~recs = Array.fill( ~numInputs, {
		arg recorder;
		recorder = Recorder(s);
		recorder.recHeaderFormat_('wav');
		recorder.recSampleFormat_("int16");
		recorder;
});

	// allocate buses and instances of mic synths and sine banks
	~micSamplerBuses = Array.fill(~numInputs, { Bus.audio(s, 1) } );
	// assign micSampler synths to micSamplerBuses
	~micSamplerSynths = Array.fill(~numInputs, { arg i; Synth.new(\micSampler, [\in, i, \out, ~micSamplerBuses[i] ] ) } );
	// micLive synths to analog outputs
	~micLiveSynths = Array.fill(~numInputs, { arg i; Synth.new(\micLive, [\in, i, \inputGain, 0.6, \amp, 0, \out, i] ) } );
	// sinBank synths to analog outputs
	~sinSynths = Array.fill(~numInputs, { arg i; Synth.new(\sinBank_x, [\out, i] ) } );

	s.sync;

	// build audio buffers
	Buffer.freeAll; // free anything that's already allocated

	~pianoLeftBufs = ~readInBufs.(~pianoNotesLeftDir);
	~pianoRightBufs = ~readInBufs.(~pianoNotesRightDir);

	~gMajIndexes = [0, 1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 34, 35, 36];
	~gDomIndexes = [2, 3, 5, 6, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29, 30, 28, 29, 30, 34, 35, 36];
	~blendedIndexes = [4, 5, 6, 7, 8, 9, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29, 30, 28, 29, 30, 28, 29, 30, 34, 35, 36];

	~gMajLeft = Array.fill(~gMajIndexes.size, {
		arg i;
		~pianoLeftBufs[~gMajIndexes[i]]; // return the buffer at that index
	});

	~gMajRight = Array.fill(~gMajIndexes.size, {
		arg i;
		~pianoRightBufs[~gMajIndexes[i]]; // return the buffer at that index
	});

	~gDomLeft = Array.fill(~gDomIndexes.size, {
		arg i;
		~pianoLeftBufs[~gDomIndexes[i]]; // return the buffer at that index
	});

	~gDomRight = Array.fill(~gDomIndexes.size, {
		arg i;
		~pianoRightBufs[~gDomIndexes[i]]; // return the buffer at that index
	});

	~blendedLeft = Array.fill(~blendedIndexes.size, {
		arg i;
		~pianoLeftBufs[~blendedIndexes[i]]; // return the buffer at that index
	});

	~blendedRight = Array.fill(~blendedIndexes.size, {
		arg i;
		~pianoRightBufs[~blendedIndexes[i]]; // return the buffer at that index
	});







	~cemeteryBuf = ~readInBufs.(~cemeteryDir);
	~salemCovBuf = ~readInBufs.(~salemCovDir);

	~pianoLeftPlayers = Array.fill(2, { arg i; Synth.new(\bufPlay_mono, [\out, i]) } ); // this will get set to outputs 0 and 1
	~pianoRightPlayers = Array.fill(2, { arg i; Synth.new(\bufPlay_mono, [\out, i+2]) } ); // this will get set to outputs 2 and 3 (i+2)
	~cemeteryPlayer = Synth.new(\bufPlay_stereo, [\buf, ~cemeteryBuf[0], \out, 4]);
	~salemCovPlayer = Synth.new(\bufPlay_stereo, [\buf, ~salemCovBuf[1], \amp, 3, \out, 4]);
	/*Routine.new( {
		~pianoLeftBufs = ~pianoNotesLeftDir.entries.collect( {
			arg fn;
			Buffer.read(s, fn.fullPath);
		});
	}).play;
	*/

	~pianoRoutines = Array.fill(4, {
	arg i;
	if( i < 2 ) {
			Routine.new( {

				var currentBuf;
				~pianoLeftPlayers[i].set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
				fork{
					Task.new( {
						~pianoWaitTime.wait; // wait before starting recording
						~recs[i].record(~temps[i], ~micSamplerBuses[i], numChannels: 1); // start recording
						~sampleDur.wait; // wait for recording
						~recs[i].stopRecording; // stop recording
						~recBufTime.wait; // wait to make sure recording saves
						~localHost.sendMsg('/ping', i); // ping local server
						~pingBufTime.wait; // give ping some time for response



						~sinSynths[i].set(\gate, 0); // turn off
						["OFF"].postln;
						0.11.wait; // for release

						~sinSynths[i].set(\freqs, ~currentData[i][1]);
						~sinSynths[i].set(\amps, ~currentData[i][0]); // set
						~sinSynths[i].set(\gate, 1); // turn back on

						~synthSusTime.wait;
						~sinSynths[i].set(\release, 4, \gate, 0); // need to reset this elsewhere for hard cuts


					});
				};


			});
		} {
			Routine.new( {
				~pianoRightPlayers[i-2].set(\buf, ~pianoRightBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
			});
		};
	});

	s.sync;

	// test output
	//~pianoLeftPlayers[[0,1].choose].set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
	//~pianoRightPlayers[[0,1].choose].set(\buf, ~pianoRightBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
});

s.meter;

)

~pianoRoutines[0].reset;
~pianoRoutines[0].next;
~cemeteryPlayer.set(\gate, 0);
~salemCovPlayer.set(\gate, 0);




//~sinSynths[0].set(\gate, 0);
//~micLiveSynths[0].set(\inputGain, 1);
//~pianoLeftPlayers[[0,1].choose].set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
//~pianoRightPlayers[[0,1].choose].set(\buf, ~pianoRightBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);

//x = Synth.new(\bufPlay_mono, ~pianoLeftBufs[0]);
//x.set(\buf, ~pianoLeftBufs.choose, \startPos, 0, \t_trig, 1, \gate, 1);
//x.set(\gate, 1);
//~pianoLeftBufs.choose;