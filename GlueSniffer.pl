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

sub fetch_archive{

    my $content = get("http://pastebin.com/archive");

    # Get pastes
    my @pastes = ($content =~/(class=\"i_p0".*\n.*\n.*)/g);
    
    my %archive = ();

    # Get link, type and name
    foreach my $link (@pastes){
        $link =~ /href="\/(.*?)">(.*?)<.*href.*">(.*?)<\//s;
        $archive{$1} = [$2, $3];
    }
    
    return %archive;
}

my %regexps = parse_matchlist $filename;

my %archive = ();
my %last_archive = ();

while(1){

    %last_archive = %archive;
    undef(%archive);

    %archive = fetch_archive;
    
    # Go through all the pastes
    foreach my $key (keys %archive){
        if(exists($last_archive{$key})){next;}
        
        $content = get("http://pastebin.com/raw.php?i=$key");
    }
}
