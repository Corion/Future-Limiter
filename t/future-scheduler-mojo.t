#!perl -w
use strict;
use Test::More;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;

# We want to use/force the Mojo backend
BEGIN {
	my $ok = eval {
		require Future::Mojo;
		1
	};
	if( ! $ok ) {
		plan skip_all => "$@";
		exit 0;
	} else {
		plan tests => 1;
	};
};

use Future::Scheduler::Functions qw(sleep);

my $start = time;

my $sleep = sleep(2);
$sleep->get();

my $done = time;
my $taken = $done - $start;

cmp_ok( $taken, '>=',  2, "We slept at least 2 seconds" );
is $Future::Scheduler::implementation, 'Future::Scheduler::Mojo', "We used the Mojo backend";