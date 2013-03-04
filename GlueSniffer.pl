#!/usr/bin/perl

use v5.14;
use Getopt::Long;
use LWP::Simple;

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

# Params: string to be weighed, matchlist hash reference
sub calculate_weight{
    my $content = shift;
    my $regexps_ref = shift;

    my $weight = 0;
    
    foreach my $regexp (keys %{$regexps_ref}){
        my $matches = () = $content =~ m/$regexp/g; # Find the number of matches
        $weight += ($regexps_ref->{$regexp} * $matches);
    }

    return $weight;    
}

my $match_file = "match.txt";
my $pastes_dir = "pastes";

GetOptions('match=s' => \$match_file, 'directory=s' => \$pastes_dir);

my %regexps = parse_matchlist $match_file;

my %archive = ();
my %last_archive = ();

if(-e $pastes_dir && !-d $pastes_dir){ die "$pastes_dir is not a directory\n"; }
if(!-e $pastes_dir && !mkdir $pastes_dir){ die "Unable to create directory $pastes_dir\n"; }

while(1){

    %last_archive = %archive;
    undef(%archive);

    %archive = fetch_archive;
  
    # Go through all the pastes
    foreach my $key (keys %archive){
        if(exists($last_archive{$key})){next;}
 
        my $link = "http://pastebin.com/raw.php?i=$key";
        my $content = get($link);
        
        if(calculate_weight($content, \%regexps) > 50){
            open FILE, ">", "$pastes_dir/$key" or die "Unable to create file $pastes_dir/$key";
            print "$link\n";
            print FILE $content;
            close FILE;
        }
    }

    sleep(30);  # No use running it to often
}
