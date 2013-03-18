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
    my $key = shift; #for debug

    my $weight = 0;

    my $debug_regs = "";
            
    foreach my $regexp (keys %{$regexps_ref}){
        my $matches = () = $content =~ m/$regexp/g; # Find the number of matches
        if($matches){
            $weight += ($regexps_ref->{$regexp} * $matches);
            $debug_regs .= "$matches * $regexp = " . $regexp_refs->{$regexp}*$matches . "\n";
        }
    }

    if($weight >= 50){
        my $date = `date "+%F %R"`;
        chomp $date;
        open DEBUG, ">>", "debug.txt";
        print DEBUG "$date $key\n$debug_regs\nTotal: $weight\n";
        close DEBUG;
    }

    return $weight;    
}

my $helptext = 
"Usage: $0 <options>

    -h  --help      Shows this information
    -m  --match     The name of file containing the match strings (Default: match.txt)
    -d  --dir       The directory where pastes will be saved (Default: pastes)";

my $match_file = "match.txt";
my $pastes_dir = "pastes";
my $help;

GetOptions('match=s' => \$match_file, 'dir=s' => \$pastes_dir, 'help' => \$help);

if($help){
    print $helptext, "\n";
    exit;
}

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
        
        if(calculate_weight($content, \%regexps, $key) >= 50){
            open FILE, ">", "$pastes_dir/$key" or die "Unable to create file $pastes_dir/$key";
            binmode(FILE, ":utf8");
            print "$link\n";
            print FILE $content;
            close FILE;
        }

        sleep(2);   # Seems I'm still getting banned
    }

    sleep(20);  # No use running it to often
}
