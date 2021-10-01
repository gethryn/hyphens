#!/usr/bin/perl

use strict;
use warnings;
use 5.18.0;
use utf8;
binmode(STDOUT, "encoding(UTF-8)");

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

# open the text file with the non eligible hyphens to check.
my $wordfile = $ARGV[0] ||= "NonElligibleHyphenWords.txt";
open (WFH, '< :encoding(UTF-8)', $wordfile) or die "Can't open input file '$wordfile': $!";

# # import the words into an array
chomp(my @non_eligible = <WFH>);

# # close the file again
close WFH or die "Can't close file: $!";

my $regex_noneligible = join "|", @non_eligible;
$regex_noneligible = qr/(-+\s*\b(?:$regex_noneligible)\b|\b(?:$regex_noneligible)\b\s*-+)/i;

print "\n\n Non-Eligible Word Pattern: $regex_noneligible";

print STDOUT "\n================================================================================\n\n";

# regex to look for hyphenated words
my $regex = qr/\w+\s*-+\s*\w+/; # any word with hyphen(s); possible spaces around hyphen
my $regex_emdashes = qr/(\s+-\s+|\s*-{2,}\s*)/;  # this subset are probably em-dashes
my $regex_multi_hyphen = qr/\w+(?:-\w+){2,}/; # more than one hypehen in a word -- ignore these
my $regex_repeated_word = qr/(\w+)\s*-\s*(\1)/; # stuttering
my $regex_emphasis = qr/\s-\w+?-\s/; # I know him -too- well.
my $regex_broken_dialogue = qr//; # ends with a hyphen

# # Open Each Text File
foreach (@textfiles) {
    my $textfile = "html/" . $_;
    # my $textfile_out = $textfile =~ s/(\.txt|\.html)/_clean$1/gr;

    print STDOUT "\n\n--------------------------------------------------------------------------------\n";
    print STDOUT "Scanning [$textfile]: \n";
    print STDOUT "--------------------------------------------------------------------------------\n";

    my $i = 0;
    my @all_matches;
    open (FH, '< :encoding(UTF-8)', $textfile) or die "Can't open input file '$textfile': $!";
    # open (FHOUT, '>', $textfile_out) or die "Can't open output file '$textfile_out': $!";
    while (<FH>) {
        my $line = $_;

        my $para_start = qr/\s*\<p[^>]+\>\s*./; # only p tags
        my $before = " …’”‘“\"'"; # boundary conditions before search term
        my $after = " ,.…‘'’;:?!”“\""; # boundary conditions after search term
        
        # get a list of the matches
        if ($line =~ m/$para_start/) { # starts with p-tag
            my @matches = $line =~ m/(?<=[$before])($regex)(?=\s*[$after])/g;
            my @matches_startline = $line =~ m/^($regex)(?=\s*[$after])/g;
            my @matches_multiline = $line =~ m/($regex_multi_hyphen)/g;
            my @matches_noneligible = $line =~ m/($regex_noneligible)/g;
            # and count them
            my $count = scalar @matches + scalar @matches_startline + 
                scalar @matches_multiline + scalar @matches_noneligible;

            my @matches_line = uniq(@matches, @matches_startline, @matches_multiline,
                @matches_noneligible);

            if ($count != 0) {
                print STDOUT "[$count \@ line $.: ";
                print STDOUT join "; ", @matches_line;
                print STDOUT "] -> " . $line =~ s/\s*\<[^>]+?\>//gr; # remove html tags
            }    

            if ($count > 0) { # we have hyphens

                my %replace;
                my @values;

                ### emphasis --------------------------------------
                
                my @matches_emphasis = $line =~ m/$regex_emphasis/g;
                @matches_emphasis = uniq(@matches_emphasis);
                @values = map { $_ =~ s/\s-(\w+?)-\s/ \<i\>$1\<\/i\> /gr } @matches_emphasis;
                @replace{@matches_emphasis} = @values;

                print STDOUT "  emphasis => ";
                print STDOUT map { "$_ = $replace{$_}; " } @matches_emphasis;
                print STDOUT "\n";

                ### APPLY SUBST non-eligible here to remove from future consideration
                $line = $line =~ s/$_/$replace{$_}/egr for @matches_emphasis;
                #$line =~ map { s/($_)/$replace{$1}/gr } @matches_emphasis;

                # double hyphens to em-dash
                my @matches_emdash = $line =~ m/$regex_emdashes/g;
                @matches_emdash = uniq(@matches_emdash);
                @values = map { $_ =~ s/\s*-{2,}\s*/—/gr } @matches_emdash;
                @replace{@matches_emdash} = @values;

                print STDOUT "  emdash => ";
                print STDOUT map { "$_ = $replace{$_}; " } @matches_emdash;
                print STDOUT "\n";

                ### APPLY SUBST emdash here to remove from future consideration
                #$line =~ s///g;

                # non eligible hypens -> emdash. ------------------
                @matches_noneligible = uniq(@matches_noneligible);
                @values = map { $_ =~ s/\s*-+\s*/—/gr } @matches_noneligible;

                @replace{@matches_noneligible} = @values;

                print STDOUT "  noneleg => ";
                print STDOUT map { "$_ = $replace{$_}; " } @matches_noneligible;
                print STDOUT "\n";

                ### APPLY SUBST non-eligible here to remove from future consideration
                #$line =~ s///g;



            }

            if ($count != 0) {
                print STDOUT "[FIXED] ->> " . $line =~ s/\s*\<[^>]+?\>//gr; # remove html tags
                print STDOUT "\n\n";
            } 

        # # fix any words that matched
        # $line =~ s/(?<=[$before])($regex)(?=[$after])/$replace{$1}/g;
        # $line =~ s/^($regex)(?=[$after])/$replace{$1}/g;
       
        # output the line to the cleaned file
        # print FHOUT $line; 

        #add the matches to the list of all matches for the file
            @all_matches = uniq(@all_matches, @matches_line);

        # count the instance of a match
            $i += $count;
            #add the matches to the list of all matches for the file
            @all_matches = uniq(@all_matches, @matches, @matches_startline);
        }

    }
    
    close FH or die "Can't close file: $!";
    # close FHOUT or die "Can't close file: $_";

    my @cleaned_matches = grep { $_ !~ m/$regex_noneligible/gi } @all_matches; # remove excluded hyphen words
    @cleaned_matches = grep { $_ !~ m/$regex_emdashes/gi } @cleaned_matches; # remove likely em-dashes
    @cleaned_matches = grep { $_ !~ m/$regex_multi_hyphen/gi } @cleaned_matches;  # remove words with multiple hyphens

    my @dirty_matches = grep { m/($regex_noneligible|$regex_emdashes|$regex_multi_hyphen)/gi } @all_matches;  # remove words with multiple hyphens

    my $uniq = scalar @all_matches; # count unique matches
    my $cleaned = scalar @cleaned_matches; 
    my $dirty = scalar @dirty_matches; 

    print STDOUT "\n\n--------------------------------------------------------------------------------\n";
    print STDOUT "Found $uniq instances of hyphenated word(s).\nI think these " . $dirty . " words need to be fixed:\n";
    print STDOUT "--------------------------------------------------------------------------------\n";
    print STDOUT join "; ", grep { m/$regex/g } sort { "\L$a" cmp "\L$b" } @dirty_matches;
    print STDOUT "\n\nThese $cleaned hyphenated words remain.\n";
    print STDOUT "--------------------------------------------------------------------------------\n";
    print STDOUT join "; ", grep { m/$regex/g } sort { "\L$a" cmp "\L$b" } @cleaned_matches;
    print STDOUT ".\n--------------------------------------------------------------------------------\n\n";
}

print STDOUT "\n\nCompleted at " . localtime() . "\n";
print STDOUT "================================================================================";
