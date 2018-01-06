#!perl -w
use strict;
use Test::More tests => 4;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Future;
use Future::AsyncAwait;

# We want to use/force the AnyEvent backend for now
use AnyEvent::Future;

use Future::Limiter;

use Data::Dumper;

# This one won't work with a lexical variable(?!)
# Most likely a bug in Async::Await
our $limiter = Future::Limiter->new(
    burst => 5,
    rate  => 30/60, # 0.5/s
);

#warn Dumper $limiter;

async sub limit_test {
    my( $j ) = @_;

    die "No more limiter for $j" unless $limiter;
    my $l = $limiter->limit;
    my $token = await $l;
    return $j
    #
};

my $started = time;
my @elements = Future->wait_all( map {
    limit_test( $_ );
} 1..10)->get;

my $finished = time;

@elements = map { $_->get } @elements;
is_deeply( \@elements, [1..10], "We get the expected results, in order")
    or diag Dumper \@elements;
my $taken = $finished - $started;
cmp_ok $taken, '<', 11, "We took less than 11 seconds";
cmp_ok $taken, '>', 5, "We took more than 5 seconds";
is $taken, 10, "We took exactly 10 seconds (5 burst + 5*2 seconds for the rest)";
