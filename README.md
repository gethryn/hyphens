# hyphens
Fixing hyphens and dashes in text

## Base directory
The base directory is the directory where you have the scripts installed.  Probably `~/Development/hyphens` or something similar.  Navigate there with `cd Development/hyphens`.

Update the program to latest with `git pull` and send you updates back to the server with `git push`.

## Input files
Input files should be added to the `html` directory with an extension of `.html` or `.txt`.  They should have `UTF-8` encoding (most will, but you can open it in VS Code and look at bottom right og the screen between `Ln xx, Col yyy  Spaces:4` and `LF` to check.)  You need UTF-8 to make sure any characters, including é, ç, em-dashes, etc., not in basic ASCII are properly interpreted.

## Run the Program
Run the program by entering the following command in terminal from the base directory:
```bash
perl fixHyphens.pl
```
If you want to see dignostic output:
```bash
perl fixHyphens.pl debug
```

If you want to send diagnostic output to a file to look at in more detail:
```bash
perl fixHyphens.pl debug > output.txt
```

## List of Non-Eligible Hyphen Words
A text list of words that should never have hyphens next to them is in `NonEligibleHyphenWords.txt`. This file can be edited to add new words using standard regex, e.g. for `that's` and `that'd` you can add an entry `that.[sd]` (*note: I aready did*).

This is compiled to a regex string like below. It is reverse sorted so longer matches match first (e.g. `you.ve` matches before `you`):
```
([^-]\b\w+?\b([–—-]\b(?:you.re|you|yet|yes|would|with|will|who|while|which|which|wherever|where|where|whenever|when|what|were|well|we.ll|we|was|us|up|until|too|to|though|those|this|they|there|then|then|them|the|that.[sd]|that|so|she|shall|see|say|out|or|on|oh|of|now|not|nor|no|never|my|more|me|maybe|may|just|its|it.s|it|is|in|if|how|his|him|here|her|he.d|he|have|has|had|from|for|every|even|else|do|did|could|come|can|camefrom|by|but|both|bmy|be|at|as|are|any|and|an|also|all|again|a|I.ve|I.m|I.ll|I)\b|\b(?:you.re|you|yet|yes|would|with|will|who|while|which|which|wherever|where|where|whenever|when|what|were|well|we.ll|we|was|us|up|until|too|to|though|those|this|they|there|then|then|them|the|that.[sd]|that|so|she|shall|see|say|out|or|on|oh|of|now|not|nor|no|never|my|more|me|maybe|may|just|its|it.s|it|is|in|if|how|his|him|here|her|he.d|he|have|has|had|from|for|every|even|else|do|did|could|come|can|camefrom|by|but|both|bmy|be|at|as|are|any|and|an|also|all|again|a|I.ve|I.m|I.ll|I)\b[–—-])\b\w+?\b[^-])
```
It looks for these words on either side of a hyphen, en-dash or em-dash, so long as there are not additional hypehnated words in the match (e.g. `father-in-law` should not match, but `father-in` on its own should).

## How it works

The application creates a series of regex expressions to test for each of the defined cases:

```perl
my $regex_noneligible = join "|", sort { $b cmp $a} @non_eligible;
$regex_noneligible = qr/[^-]\b\w+?\b([–—-]\b(?:$regex_noneligible)\b|\b(?:$regex_noneligible)\b[–—-])\b\w+?\b[^-]/i;

my $regex = qr/\w+\s*-+\s*\w+/; # any word with hyphen(s); possible spaces around hyphen
my $regex_emdashes = qr/(\s+-\s+|\s*-{2,}\s*)/;  # this subset are probably em-dashes
my $regex_multi_hyphen = qr/\w+(?:-\w+){2,}/; # more than one hypehen in a word -- ignore these
my $regex_repeated_word = qr/(\b\w+\b)\s*-\s*(\1)/; # stuttering
my $regex_emphasis = qr/[$before](-\w+?-)[$after]/; # I know him -too- well.
my $regex_broken_dialogue = qr/(\b\w+?\b\s*[-]\s*[’”“‘"'])/; # ends with a hyphen
```

It then runs through each file in the `html` directory and creates an `_clean` version of the file with the edits applied.  

They are procesed in this order (so far), progressively correcting each line so that subsequent tests don't fix things that are already fixed.  I'm not certain this order is right:
1. **broken dialogue**.  When dialogue ends with a hyphen, en-dash or em-dash.
2. **emphasis** fixes `I would -never- do that` to `I would <i class="calibre5">never</i> do that`.
3. **emdashes** fixes obvious em-dashes like ` - ` with spaces and `--` with or without spaces.
4. **non-eligible** fixes any word on either side of a hyphen, en-dash or em-dash that appears in the `NonEligibileHyphenWords.txt` file, forcing it to em-dash.
5. **repeated** forces when words on either side of a hyphen, en-dash or em-dash are the same, eg. stuttering. 

The rest are deemed to be normal hyphenated words for you to check.