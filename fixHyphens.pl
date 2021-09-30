#!/usr/bin/perl

use strict;
use warnings;
use 5.18.0;

# Usage:  
    # 1st Argument: The file to containing the LL words

print STDOUT "================================================================================\n";
print STDOUT "fixHyphen Script Run at " . localtime() . "\n";

# a function to remove duplicates from an array
sub uniq (@) {
    # From CPAN List::MoreUtils, version 0.22
    my %h;
    map { $h{$_}++ == 0 ? $_ : () } @_;
}

# Get the list of txt or html files in the html directory
my @textfiles;
opendir my $dh, "html" or die "Can't open directory: $!";

while ( readdir $dh ) {
    chomp;
    next if $_ eq '.' or $_ eq '..' or $_ =~ m/_clean\./ or $_ !~ m/\.(html|txt)$/;    
    my $textfile = $_;
    push(@textfiles, $textfile);
    next;
}
my $numfiles = scalar @textfiles;

print STDOUT "* There are $numfiles file(s) to process: ";
print STDOUT join "; ", @textfiles;
print STDOUT ".\n";

# open the text file with the hyphens to check.
# my $wordfile = $ARGV[0] ||= "hyphen_words.txt";
# open (WFH, '<', $wordfile) or die "Can't open input file '$wordfile': $!";

# # import the words into an array
# chomp(my @lines = <WFH>);

# # close the file again
# close WFH or die "Can't close file: $!";

# # # # create the hash to store the words to correct
# my %replace;

# for ( @lines ) {
#     my $lookup = $_ =~ s/ll/l /gr;
#     $replace{$lookup} = $_;
# }

# # add duplicate entry with first letter capitalised for all existing entries
# @replace{ map { ucfirst } keys %replace } = map { ucfirst } values %replace;

# # find edge case: words ending in ll that don't have two spaces before next word.
# my @ends_with_ll = grep { m/l\s$/ } keys %replace;

# # output the number of entries imported
# my $num_words = scalar keys %replace;
# print STDOUT "* There are $num_words entrie(s) in the \%replace hash from [$wordfile].\n";
print STDOUT "================================================================================\n\n";

# my $regex = join "|", map { quotemeta } sort { $b cmp $a } keys %replace;
# my $regex_ends_with_ll = join "|", map { quotemeta } sort { $b cmp $a } @ends_with_ll;

# $regex = qr/$regex/;
# $regex_ends_with_ll = qr/$regex_ends_with_ll/;

# a hash to store the hyphenated words found
my %hyphen_words;

# regex to look for hyphenated words
my $regex = qr/\w+(\s*-+\s*\w+)+/;

my $regex_ignore = qr/(again|\b[hH]er\b|\b[hH]is\b|\b[nN]ow\b|\b[Tt]hat.s\b|\b[tT]hen\b|\ba\b|\ball\b|\balso\b|\ban\b|\band\b|\bany\b|\bare\b|\bas\b|\bat\b|\bboth\b|\bbut\b|\bby\b|\bcan\b|\bcome\b|\bcould\b|\bdid\b|\bdo\b|\belse\b|\beven\b|\bevery\b|\bfor\b|\bfrom\b|\bhad\b|\bhas\b|\bhave\b|\bhave\b|\bhe\b|\bhe.d\b|\bher\b|\bhere\b|\bhim\b|\bhis\b|\bhow\b|\bI\b|\bI’\b|\bif\b|\bI.m\b|I’ll\b|\bin\b|\bis\b|\bit\b|\bit.s\b|\bits\b|\bjust\b|\bmay\b|\bmaybe\b|\bme\b|\bmore\b|bmy\b|\bnever\b|\bno\b|\bnor\b|\bnot\b|\bnow\b|\bof\b|\boh\b|\bon\b|\bor\b|\bout\b|\bsay\b|\bshall\b|\bsee\b\bshe\b|\bso\b|\bthat\b|\bthe\b|\bthem\b|\bthen\b|\bthere\b|\bthey\b|\bthis\b|\bthose\b|\bthough\b|\bto\b|\btoo\b|\buntil\b|\bup\b|\bus\b|\bwas\b|\bwe\b|\bwell\b|we.ll|\bwere\b|\bwhat\b|\bwhen\b|\bwhere\b|wherever|whenever|\bwhich|\bwhile\b|\bwho\b|\bwill\b|\bwith\b|\bwould\b|\byes\b|\byet\b|\byou\b|\byou.re\b)/;

my $regex_emdashes = qr/(\s+-\s+|\s*-{2,}\s*)/;

my $regex_multi_hyphen = qr/\w+(\s*-+\s*\w+){2,}/;

# # Open Each Text File
foreach (@textfiles) {
    my $textfile = "html/" . $_;
    # my $textfile_out = $textfile =~ s/(\.txt|\.html)/_clean$1/gr;

    print STDOUT "\n\nScanning [$textfile]: \n";
    print STDOUT "--------------------------------------------------------------------------------\n";

    my $i = 0;
    my @all_matches;
    open (FH, '<', $textfile) or die "Can't open input file '$textfile': $!";
    # open (FHOUT, '>', $textfile_out) or die "Can't open output file '$textfile_out': $!";
    while (<FH>) {
        my $line = $_;
        
        my $before = " …‘“\"-"; # boundary conditions before search term
        my $after = " ,.…'’;:?!-"; # boundary conditions after search term
        my $para_start = qr/\s*\<p[^>]+\>\s*.+?/; # only p tags

        # get a list of the matches
        my @matches = $line =~ /$para_start(?<=[$before])($regex)(?=[$after])/g;
        my @matches_startline = $line =~ /$para_start($regex)(?=[$after])/g;
        # and count them
        my $count = scalar @matches + scalar @matches_startline;

        # # fix any words that matched
        # $line =~ s/(?<=[$before])($regex)(?=[$after])/$replace{$1}/g;
        # $line =~ s/^($regex)(?=[$after])/$replace{$1}/g;
       
        # output the line to the cleaned file
        # print FHOUT $line; 

        # count the instance of a match
        $i += $count;
        #add the matches to the list of all matches for the file
        @all_matches = uniq(@all_matches, @matches, @matches_startline);

    }
    
    close FH or die "Can't close file: $!";
    # close FHOUT or die "Can't close file: $_";

    my @cleaned_matches = grep { $_ !~ m/$regex_ignore/gi } @all_matches; # remove excluded hyphen words
    @cleaned_matches = grep { $_ !~ m/$regex_emdashes/gi } @cleaned_matches; # remove likely em-dashes
    @cleaned_matches = grep { $_ !~ m/$regex_multi_hyphen/gi } @cleaned_matches;  # remove words with multiple hyphens

    my @dirty_matches1 = grep { m/$regex_ignore/gi } @all_matches; # remove excluded hyphen words
    my @dirty_matches2 = grep { m/$regex_emdashes/gi } @all_matches; # remove likely em-dashes
    my @dirty_matches3 = grep { m/$regex_multi_hyphen/gi } @all_matches;  # remove words with multiple hyphens
    my @dirty_matches = uniq(@dirty_matches1, @dirty_matches2, @dirty_matches3);

    my $uniq = scalar @all_matches; # count unique matches
    my $cleaned = scalar @cleaned_matches; 

    print STDOUT "Found $uniq hyphenated word(s).\n I removed these:\n";
    print STDOUT "--------------------------------------------------------------------------------\n";
    print STDOUT join "; ", grep { m/$regex/g } @dirty_matches;
    print STDOUT "\n\nThese $cleaned cleaned matches remain.\n";
    print STDOUT "--------------------------------------------------------------------------------\n";
    print STDOUT join "; ", grep { m/$regex/g } @cleaned_matches;
    print STDOUT ".\n--------------------------------------------------------------------------------\n";
}

print STDOUT "Completed at " . localtime() . "\n";
print STDOUT "================================================================================";
