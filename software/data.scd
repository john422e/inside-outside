// data.scd

(
// global data, run this second

~numInputs = 4; // analog inputs (quartet mics)
~numOutputs = 4; // analog outputs (quartet speakers)
~numSines = 8; // how many sine waves to include in sinBank synth

// use these with the ~filterList in functions.scd

// list of frequencies from salemCov analysis
~salemCovFreqs = Array.rand(256, 60, 4000); // test version
// live generated list of freqs from mic signal
~liveFreqs = Array.rand(256, 60, 4000); // test version

// get sound file names

// audio directory
~audioDir = PathName.new( PathName.new(thisProcess.nowExecutingPath).parentPath ++ "../audio");
// piano notes filenames;
~pianoNotesLeftDir = ~audioDir +/+ PathName("piano/left");
~pianoNotesRightDir = ~audioDir +/+ PathName("piano/right");


)
