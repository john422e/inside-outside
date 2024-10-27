// functions.scd

// global functions, run this first (should not reference anything in data.scd or elsewhere)

(
~readInBufs = {
	// read in sound files to buffers
	// sound server must be on first
	arg dir;
	var bufs;
	Routine.new( {
		bufs = dir.entries.collect( {
			arg filename;
			Buffer.read(s, filename.fullPath);
		});
		s.sync;
	}).play;
	s.sync;
	bufs;
};

// add frequencies from ~liveFreqs to filtered list if they are found in ~salemCovFreqs
~filterList = {
	// returns all elements of list2 which are in list1
	arg list1, list2;
	var filteredList;
	filteredList = List.newClear;
	list2.do{
		arg i;
		if( list1.includes(i) ) { filteredList.add(i)};
	};
	filteredList;
};
)
