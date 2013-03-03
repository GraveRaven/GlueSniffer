#!/usr/bin/perl

use v5.14;
use Getopt::Long;
use LWP::Simple;

my $filename = "match.txt";

GetOptions('f=s' => \$filename);

# Parses the match list and puts it in a dictionary
sub parse_matchlist{
    my $filename = shift;
    open FILE, $filename;

    my %regexps;

    while(my $line = <FILE>){
        chomp $line;
        if(length($line) > 0 && (substr $line, 0, 1) ne "#"){
            (my $regexp, my $weight) = split "\t", $line, 2;
            if(eval {qr/$regexp/}){ # Make sure the regexp is valid
                $regexps{$regexp} = 0+ $weight; # Force the weight to be a number
            }
        }
    }

    return %regexps;
}

my %regexps = parse_matchlist $filename;

