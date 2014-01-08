#!/usr/bin/perl

use warnings;
use strict;
use v5.18;
use Getopt::Long;
use LWP::Simple;
use DBI;

our $db_user = "gluesniffer";
our $db_passwd = "nosebleed";
our $db_name = "gluesniffer";
our $db_host = "localhost";

#Connect to database
sub db_connect{
    return DBI->connect("dbi:mysql:database=$db_name;host=$db_host", $db_user, $db_passwd);
}

# Parses the match list and puts it in a dictionary
sub parse_matchlist{

    my $dbh = db_connect;
    my %regexps;
    
    foreach my $list (("whitelist", "blacklist")){

        my $sth = $dbh->prepare("SELECT expression, weight, onlyonce, category, regname FROM $list");
        $sth->execute;

    
        while(my @row = $sth->fetchrow_array){
            my $regexp = $row[0];
            my $weight = $row[1];
            my $uniq = $row[2];
            if(eval {qr/$regexp/}){ # Make sure the regexp is valid
                $regexps{$regexp} = [0+ $weight, $uniq]; # Force the weight to be a number
            }
        }
    }    

    $dbh->disconnect;

    return %regexps;
}

sub fetch_archive{

    my $content = get("http://pastebin.com/archive");
    return unless $content;

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

    my $total_weight = 0;

    my $debug_regs = "";
            
    foreach my $regexp (keys %{$regexps_ref}){
        my $nr_matches =(my @matches)= $content =~ m/$regexp/g; # Find the number of matches
        if($nr_matches){
            (my $weight, my $uniq) = @{$regexps_ref->{$regexp}};
            if($uniq){
                $nr_matches = values{map{$_ => 1} @matches}; #makes sure every unique instance of a match is only counted once.
            }

            $total_weight += ($weight * $nr_matches);
            $debug_regs .= "$nr_matches * $regexp = " . $weight * $nr_matches . "\n";
        }
    }

    if($total_weight >= 50){
        print "Printing debug\n";
        my $date = `date "+%F %R"`;
        chomp $date;
        open DEBUG, ">>", "debug.txt";
        print DEBUG "$date $key\n" , $debug_regs, "Total: $total_weight\n\n";
        close DEBUG;
    }

    return $total_weight;    
}

sub save_paste{
    my $key = shift;
    my $content = shift;

    my $dbh = db_connect;
    my $sth = $dbh->prepare("SELECT content FROM finding WHERE pasteid = ?");
    $sth->execute($key);
    
    if($sth->rows == 0){
        $sth = $dbh->prepare("INSERT INTO finding (pasteid, time, content) values (?,NOW(),?)");
        $sth->execute($key, $content); 
    }
    
    $dbh->disconnect;
}

my $helptext = 
"Usage: $0 <options>

    -h  --help      Shows this information
";

my $help;

GetOptions('help' => \$help);

if($help){
    print $helptext, "\n";
    exit;
}
my %regexps = parse_matchlist;

my %archive = ();
my %last_archive = ();

while(1){

    %last_archive = %archive;
    undef(%archive);

    %archive = fetch_archive;
    
    if(%archive){
        # Go through all the pastes
        foreach my $key (keys %archive){
            if(exists($last_archive{$key})){next;}
 
            my $link = "http://pastebin.com/raw.php?i=$key";
            my $content = get($link);
            next unless $content;
            if(calculate_weight($content, \%regexps, $key) >= 50){
                save_paste($key, $content);
            }

            sleep(2);   # Seems I'm still getting banned
        }
    }

    sleep(20);  # No use running it to often
}
