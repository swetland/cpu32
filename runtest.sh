#!/bin/sh

if ./a32 $1 $1.txt ; then
	echo OKAY: ASSEMBLED $1
else
	echo FAIL: ERROR ASSEMBLING $1
	exit 1
fi

if vvp testbench +ROM=$1.txt > $1.out ; then
	echo OKAY: EXECUTED $1
else
	echo FAIL: ERROR EXECUTING $1
	exit 1
fi

grep '^PC> ' $1.out | grep -v HAZARD > $1.trace

if [ ! -f $1.gold ] ; then
	cp $1.trace $1.gold
	echo "---- ---- ---- ---- ---- ---- ---- ---- ----"
	cat $1.txt
	echo "---- ---- ---- ---- ---- ---- ---- ---- ----"
	cat $1.gold
	echo "---- ---- ---- ---- ---- ---- ---- ---- ----"
	echo FAIL: MISSING GOLDEN MASTER $1.gold
	echo FAIL: PLEASE INSPECT THE TRACE ABOVE
	exit 1
fi

if diff $1.trace $1.gold ; then
	echo OKAY: VERIFIED $1
else
	echo FAIL: VERIFICATION FAILED $1
	exit 1
fi

exit 0
