#!perl

use 5.010001;
use strict;
use warnings;
use Test::More 0.98;

use File::Temp qw(tempdir);
use Logfile::Tail::Timestamp;
use Time::HiRes 'sleep';

my $tempdir = tempdir();

subtest "single glob" => sub {
    my $dir = "$tempdir/1";
    mkdir $dir, 0755 or die;

    open my $fha, ">>", "log-a"; $fha->autoflush(1); print $fha "one-a\n";
    open my $fhb, ">>", "log-b"; $fhb->autoflush(2); print $fhb "one-b\ntwo-b\n";
    my $tail = Logfile::Tail::Timestamp->new(
        globs => ["$dir/log-*"],
    );
    is_deeply($tail->getline, undef, "initial");
    print $fha "two-a\n"; sleep 1;
    is_deeply($tail->getline, undef, "line added to log-a has no effect");
    print $fhb "three-b\nfour-b\n";
    $tail->getline;
    is_deeply($tail->getline, "three-b\n", "line added to log-b is seen (1)");
    is_deeply($tail->getline, "four-b\n", "line added to log-b is seen (2)");
};

subtest "two globs" => sub {
    my $dir = "$tempdir/2";
    mkdir $dir, 0755 or die;

    ok 1;
};

done_testing;
