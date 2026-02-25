#!/usr/bin/env bash

# Vars so as not to clog PATH
wla_cpu=$HOME/bin/wladx/wla-z80
wlalink=$HOME/bin/wladx/wlalink

# Get current dir name
dirname=${PWD##*/}
dirname=${dirname:-/}

# Check rebuild flag
[ "$1" = "-r" ]; rm -f "$dirname.sms" *.lst *.sym

# Back up previous build
if [ -f "$dirname.sms" ]; then
	mkdir -p old
	num=1

	while [ -f "old/${dirname}_$num.sms" ]; do
		num=$(($num+1))
	done

	mv "$dirname.sms" "old/${dirname}_$num.sms"
fi

# Create object file
echo Creating object file...
$wla_cpu -o $dirname.o ./main.asm

# Stop if that failed
result=$?
[ $result -eq 0 ] || exit $result

# Generate linker script
echo [objects]>linkfile
echo $dirname.o>>linkfile

# Link everything
echo Linking...
$wlalink -S -v linkfile $dirname.sms

# Clean up
rm $dirname.o linkfile
