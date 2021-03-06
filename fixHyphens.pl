#!/usr/bin/perl

use strict;
use warnings;
use 5.18.0;
use utf8;
use List::Util 'sum';
binmode(STDOUT, "encoding(UTF-8)");

# Usage:  
    # 1st Argument: debug flag
    # 2nd Argument: filename for non-eligible hyphen words

my $DEBUG = $ARGV[0] ||= 0;
my $wordfile = $ARGV[1] ||= "NonElligibleHyphenWords.txt";

# variables used in
my $para_start = qr/\s*\<p[^>]+\>\s*./; # only p tags
my $before = " …’”‘“\"'"; # boundary conditions before search term
my $after = " ,.…‘'’;:?!”“\""; # boundary conditions after search term

print STDOUT "================================================================================\n";
print STDOUT "fixHyphen Script Run at " . localtime() . "\n\n";

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

print STDOUT "There are $numfiles file(s) to process: \n*\t";
print STDOUT join "\n*\t", @textfiles;
print STDOUT "\n";

# open the text file with the non eligible hyphens to check.
open (WFH, '< :encoding(UTF-8)', $wordfile) or die "Can't open input file '$wordfile': $!";

# # import the words into an array
chomp(my @non_eligible = <WFH>);

# # close the file again
close WFH or die "Can't close file: $!";

my $regex_noneligible = join "|", sort { $b cmp $a} @non_eligible;
$regex_noneligible = qr/(?<![-])(?<![-])((?:\b\w+?\b|\))[-]\b(?:$regex_noneligible)\b|\b(?:$regex_noneligible)\b[-](?:\(|\b\w+?\b))(?![-])/i;

# regex to look for hyphenated words
my $regex = qr/\w+\s*-+\s*\w+/; # any word with hyphen(s); possible spaces around hyphen
my $regex_emdashes = qr/(?<!\d)(\s+-\b|\b-\s+|\s+-\s+|\s*-{2,}\s*)(?!\d)/;  # this subset are probably em-dashes
my $regex_multi_hyphen = qr/\w+(?:-\w+){2,}/; # more than one hypehen in a word -- ignore these
my $regex_repeated_word = qr/(\b\w+\b)\s*-\s*(\1)/; # stuttering
my $regex_emphasis = qr/[$before](-[^-]+?-)[$after]/; # I know him -too- well.
my $regex_broken_dialogue = qr/(\b\w+?\b\s*[-]\s*[’”“‘"']|\W[’”“‘"']\s*[-]\s*\b\w+?\b)/; # ends with a hyphen
my $regex_hyphenated_with_numbers = qr/((?<=\d)\s*-\s*(?=\w)|(?<=\w)\s*-\s*(?=\d))/; # e.g. "MIG -25" or "MIG- 25"-> "MIG-25"
my $regex_after_punct = qr/[[:punct:]]-/; #20

print "\n\nNon-Eligible Word Pattern generated from $wordfile:\n\n$regex_noneligible";

print STDOUT "\n================================================================================\n\n";

# # Open Each Text File
foreach (@textfiles) {
    my $textfile = "html/" . $_;
    my $textfile_out = $textfile =~ s/(\.txt|\.html)/_clean$1/gr;

    print STDOUT "\n\nScanning [$textfile]: \n";
    print STDOUT "--------------------------------------------------------------------------------\n";

    my @all_matches;

    open (FH, '< :encoding(UTF-8)', $textfile) or die "Can't open input file '$textfile': $!";
    open (FHOUT, '> :encoding(UTF-8)', $textfile_out) or die "Can't open output file '$textfile_out': $!";

    print STDOUT "* Parsing hyphens...\n";
    my %counter; # for output

    $counter{'hyphen'} = 0;
    $counter{'broken_dialogue'} = 0;
    $counter{'emphasis'} = 0;
    $counter{'emdash'} = 0;
    $counter{'noneligible'} = 0;
    $counter{'repeated'} = 0;
    $counter{'with_numbers'} = 0;
    $counter{'after_punct'} = 0;

    while (<FH>) {
        my $line = $_;
        
        # get a list of the matches
        if ($line =~ m/$para_start/) { # starts with p-tag
            my @matches_line = $line =~ m/-/g;

            # and count them
            my $count = scalar @matches_line;
            $counter{'hyphen'} += $count;

            if ($count != 0 and $DEBUG) {
                print STDOUT "[$count \@ line $.: ";
                print STDOUT join "; ", @matches_line;
                print STDOUT "] -> " . $line =~ s/\s*\<[^>]+?\>//gr; # remove html tags
            } 


            if ($count > 0) { # we have hyphens

                my %replace;
                my @values;

                # broken dialogue to em-dash ----------------------------------
                my @matches_broken_dialogue = $line =~ m/$regex_broken_dialogue/g;
                $counter{'broken_dialogue'} += scalar @matches_broken_dialogue;
                @matches_broken_dialogue = uniq(@matches_broken_dialogue);
                @values = map { s/\s*-\s*/—/gr } @matches_broken_dialogue;

                @replace{@matches_broken_dialogue} = @values;

                if ($DEBUG) { 
                    print STDOUT "  brkdialogue => ";
                    print STDOUT map { "$_ = $replace{$_}; " } sort @matches_broken_dialogue;
                    print "\n";
                }

                # APPLY SUBST to remove from future consideration
                for (@matches_broken_dialogue) {
                    my $m = quotemeta $_; # there might be parenthesis in the matches, need to quotemeta
                    $line =~ s/$m/$replace{$_}/eg;
                }
                %replace = (); # clear the replace hash

                
                # emphasis ----------------------------------------------------
                
                my @matches_emphasis = $line =~ m/$regex_emphasis/g;
                $counter{'emphasis'} += scalar @matches_emphasis;
                @matches_emphasis = uniq(@matches_emphasis);
                @values = map { s/-([^-]+?)-/<i class=\"calibre5\">$1<\/i>/gr } @matches_emphasis;

                # Add the matches to the replace hash
                @replace{@matches_emphasis} = map {$_} @values;

                if ($DEBUG) {
                    print STDOUT "  emphasis => ";
                    print STDOUT map { "$_ = $replace{$_}; " } sort @matches_emphasis;
                    print STDOUT "\n";
                }
                ### APPLY SUBST to remove from future consideration
                $line =~ s/$_/$replace{$_}/eg for @matches_emphasis;
                %replace = (); # clear the replace hash

                # double hyphens to em-dash -----------------------------------
                my @matches_emdash = $line =~ m/$regex_emdashes/g;
                $counter{'emdash'} += scalar @matches_emdash;
                @matches_emdash = uniq(@matches_emdash);
                @values = map { s/$_/—/gr } @matches_emdash;
                
                @replace{@matches_emdash} = @values;

                if ($DEBUG) {
                    print STDOUT "\t\temdash => ";
                    print STDOUT map { "'$_' = '$replace{$_}'; " } @matches_emdash;
                    print STDOUT "\n";
                }

                ### APPLY SUBST to remove from future consideration
                $line =~ s/$_/$replace{$_}/eg for @matches_emdash;
                %replace = (); # clear the replace hash
                
                
                # non eligible hypens -> emdash. ------------------------------
                my @matches_noneligible = $line =~ m/($regex_noneligible)/g;
                $counter{'noneligible'} += scalar @matches_noneligible;
                @matches_noneligible = uniq(@matches_noneligible);
                @values = map { s/\s*-+\s*/—/gr } @matches_noneligible;

                @replace{@matches_noneligible} = @values;

                if ($DEBUG) {
                    print STDOUT "\t\tnoneleg => ";
                    print STDOUT map { "$_ = $replace{$_}; " } @matches_noneligible;
                    print STDOUT "\n";
                }

                # APPLY SUBST to remove from future consideration
                for (@matches_noneligible) {
                    my $m = quotemeta $_; # there might be parenthesis in the matches, need to quotemeta
                    $line =~ s/$m/$replace{$_}/eg;
                }
                %replace = (); # clear the replace hash

                # repeated words to em-dash -----------------------------------
                my @matches_repeated = $line =~ m/$regex_repeated_word/g;
                $counter{'repeated'} += scalar @matches_repeated;
                @matches_repeated = uniq(@matches_repeated);
                @values = map { s/\s*-+\s*/—/gr } @matches_repeated;

                @replace{@matches_repeated} = @values;

                if ($DEBUG) {
                    print STDOUT "  repeat => ";
                    print STDOUT map { "$_ = $replace{$_}; " } @matches_repeated;
                    print STDOUT "\n";
                }

                # APPLY SUBST to remove from future consideration
                $line =~ s/$_/$replace{$_}/eg for @matches_repeated;
                %replace = (); # clear the replace hash

                # hyphenated words with numbers
                my @matches_hyphenated_with_numbers = $line =~ m/$regex_hyphenated_with_numbers/g;
                $counter{'with_numbers'} += scalar @matches_hyphenated_with_numbers;
                @matches_hyphenated_with_numbers = uniq(@matches_hyphenated_with_numbers);
                @values = map { s/\s//gr } @matches_hyphenated_with_numbers;

                @replace{@matches_hyphenated_with_numbers} = @values;

                if ($DEBUG) {
                    print STDOUT "  withnums => ";
                    print STDOUT map { "$_ = $replace{$_}; " } @matches_hyphenated_with_numbers;
                    print STDOUT "\n";
                }

                # APPLY SUBST to remove from future consideration
                for (@matches_hyphenated_with_numbers) {
                    my $m = quotemeta $_; #hyphens not allowed in key
                    $line =~ s/$m/$replace{$_}/eg;
                }
                # $line =~ s/$_/$replace{$_}/eg for @matches_hyphenated_with_numbers;
                %replace = (); # clear the replace hash

                # hyphens after punctuation
                my @matches_after_punct = $line =~ m/$regex_after_punct/g;
                $counter{'after_punct'} += scalar @matches_after_punct;
                @matches_after_punct = uniq(@matches_after_punct);
                @values = map { s/-/—/gr } @matches_after_punct;

                @replace{@matches_after_punct} = @values;

                if ($DEBUG) {
                    print STDOUT "  afterpunct => ";
                    print STDOUT map { "$_ = $replace{$_}; " } @matches_after_punct;
                    print STDOUT "\n";
                }

                # APPLY SUBST to remove from future consideration
                for (@matches_after_punct) {
                    my $m = quotemeta $_; #hyphens not allowed in key
                    $line =~ s/$m/$replace{$_}/eg;
                }
                # $line =~ s/$_/$replace{$_}/eg for @matches_hyphenated_with_numbers;
                %replace = (); # clear the replace hash

            }

            if ($count != 0 and $DEBUG) {
                print STDOUT "[FIXED] ->> " . $line =~ s/^\s*\<[^>]+?\>//gr; # remove html tags
                print STDOUT "\n\n";
            } 

        #add the matches to the list of all matches for the file
        @all_matches = uniq(@all_matches, @matches_line);

        }

        # output the line to the cleaned file
        print FHOUT $line; 

        $counter{'line'} = $.;
    }

    print STDOUT "\t-> broken dialogue: " . $counter{'broken_dialogue'};
    print STDOUT "\n\t-> emphasis: " . $counter{'emphasis'};
    print STDOUT "\n\t-> apparent emdash: " . $counter{'emdash'};
    print STDOUT "\n\t-> non-eligible: " . $counter{'noneligible'};
    print STDOUT "\n\t-> repeated: " . $counter{'repeated'};
    print STDOUT "\n\t-> with numbers: " . $counter{'with_numbers'};
    print STDOUT "\n\t-> after punctuation: " . $counter{'after_punct'} . "\n\n";
    
    close FH or die "Can't close file: $!";
    close FHOUT or die "Can't close file: $!";

    my $fixed_count = sum values %counter; 
    $fixed_count -= $counter{'line'};
    $fixed_count -= $counter{'hyphen'};

    print STDOUT "* File contained $counter{'line'} lines.\n";
    print STDOUT "* Adjusted " . $fixed_count ." unique hyphenated word(s) from " . 
                    $counter{'hyphen'} . " total hyphen(s) detected.\n";
    print STDOUT "* Wrote output to [$textfile_out].\n";
    
    if ($DEBUG) {
        print STDOUT "--------------------------------------------------------------------------------\n";
        print STDOUT join "; ", grep { m/$regex/g } sort { "\L$a" cmp "\L$b" } @all_matches;
        print STDOUT ".\n--------------------------------------------------------------------------------\n\n";
    }
}

print STDOUT "\n\nCompleted at " . localtime() . "\n";
print STDOUT "================================================================================";
