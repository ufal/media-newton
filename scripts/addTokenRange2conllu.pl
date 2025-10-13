#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

my $offset = 0;

while (<>) {
    chomp;

    # Skip comment lines, print as-is
    if (/^#/) {
        print "$_\n";
        next;
    }

    # Empty lines (sentence boundaries) — treat as one space
    if (/^$/) {
        print "\n";
        $offset += 1;  # one space between sentences
        next;
    }

    my @cols = split /\t/;
    $cols[9] //= '_';
    my $form = $cols[1];

    # Compute start and end offsets (end-exclusive)
    my $start = $offset;
    my $end   = $start + length($form);

    # Append ranges to MISC
    if ($cols[9] eq '_') {
        $cols[9] = '';
    } else {
        $cols[9] .= '|';
    }
    $cols[9] .= "TokenRange=$start:$end";

    # Determine space after
    my $space_after = ($cols[9] =~ /SpaceAfter=No/) ? 0 : 1;

    # Update offset
    $offset = $end + $space_after;

    print join("\t", @cols), "\n";
}