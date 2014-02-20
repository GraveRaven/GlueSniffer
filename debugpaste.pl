#!/usr/bin/perl

############################
#                          #
# Takes pasteid's as input #
# Prints debug info        #
#                          #
############################

use warnings;
use strict;
use v5.18;
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

# Params: string to be weighed, matchlist hash reference
sub calculate_weight{
    my $content = shift;
    my $regexps_ref = shift;
    my $key = shift;
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

        print "$key\n" , $debug_regs, "Total: $total_weight\n\n";

    return $total_weight;    
}


my @pastes = @ARGV;

my %regexps = parse_matchlist;


my $dbh = db_connect;
foreach my $pasteid (@pastes){
    chomp($pasteid);

    my $sth = $dbh->prepare("SELECT content FROM finding WHERE pasteid = ?");
    $sth->execute($pasteid);
    
    my @row = $sth->fetchrow_array;
    calculate_weight($row[0], \%regexps, $pasteid)
}
