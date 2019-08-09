#!perl -w
use strict;
use Test::More;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;

# We want to use/force the default backend
plan tests => 2;

use Future::Scheduler::Functions qw(sleep);

my $start = time;

my $sleep = sleep(2);
$sleep->get();

my $done = time;
my $taken = $done - $start;

cmp_ok( $taken, '>=',  2, "We slept at least 2 seconds" );
is $Future::Scheduler::implementation, 'Future::Scheduler::Future', "We used the trivial Future backend";