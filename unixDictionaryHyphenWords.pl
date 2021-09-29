#!/usr/bin/perl

use strict;
use warnings;
use 5.18.0;

# open the text file with the double L words.
my $wordfile = "/usr/share/dict/words";
open (WFH, '<', $wordfile) or die "Can't open input file '$wordfile': $!";

# import the words into an array
chomp(my @words = <WFH>);

# close the file again
close WFH or die "Can't close file: $!";

# regex to look for hyphenated words
my $regex = qr/\w+\s*-+\s*\w+/;

# get a list of the matches
my @matches = grep { m/$regex/ } @words;

print STDOUT join "; ", @matches;
