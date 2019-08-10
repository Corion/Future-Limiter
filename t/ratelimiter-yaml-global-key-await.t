#!perl -w
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Test::More tests => 35;
use AnyEvent::Future;

use URI;
use List::Util 'max';
use YAML qw(LoadFile);
use Future::LimiterBucket;
use Future::Limiter;
use Future::IO;

use Future::AsyncAwait;

use Data::Dumper;

my $limit = Future::Limiter->from_file( 't/ratelimits.yml' );

ok exists $limit->limits->{http_request}, "We have a limiter named 'http_request'";

# Now check that we take the time we like:
# 10 requests at 1/s with a burst of 3, and a duration of 4/req should take
# 3@0 , 1@1, 3@4, 1@5
# finishing times
# 3@4 , 1@5  3@8, 1@9

sub http_request($time, $id) {
    Future::IO->sleep( $time )->on_ready(sub {
        #warn "$id done";
    })->catch(sub{warn "Uhoh @_"})
    ->then(sub{ Future->done($id)});
}

# This approach requires that all sections we use will always be available
# in the config file. This is unlikely. Also, we don't get a good way for
# insights into the latency or min / max throughput

# Generate the URLs in interspersed order
my @urls = map {URI->new($_)}
           map {("https://example.com/$_","http://localhost/$_","http://google.com/$_")}
           (1..10);

# Now try them in per-host order
my @urls_by_host = sort @urls;

my @done;
my $start;
async sub handle_url {
    my( $url )= @_;
    my( $token ) = await $limit->limit('http_request', $url->host_port);
    my @res = await http_request(2,$url);
    push @done, [time-$start,$url];
};

for my $set (\@urls_by_host, \@urls) {

    my (@jobs);
    $start = time;
    for my $url (@urls) {
        push @jobs, handle_url( $url );
    }
    # Wait for the jobs
    Future->wait_all(@jobs)->get();

    # Now sort the elements by host
    my @res = sort { $a->[1] cmp $b->[1] } @done;

    my %res;
    for (@res) {
        push @{ $res{ $_->[1]->host_port }}, $_
    };

    is 0+@done, 30, "30 jobs completed";

    my $total = 0;
    for my $host (sort keys %res) {
        # Calculate the burst and total time
        my $taken = max( map { $_->[0] } @{ $res{ $host }});
        $total = max( $total, $taken );
        cmp_ok $taken, ">=", 10-3, "Rate of 1/s per host, and a burst of 3";
        my $first = $res{$host}->[0]->[0];
        # We have a burst of three per host, but we might run in the overall
        # request limit
        cmp_ok $res{$host}->[0]->[0], '>=', $first, "Burst";
        cmp_ok $res{$host}->[1]->[0], '>=', $first, "Burst";
        cmp_ok $res{$host}->[2]->[0], '>=', $first, "Burst";
        cmp_ok $res{$host}->[-1], '>=', $first+6, "Rate/maximum";
    };
    cmp_ok $total, '>=', 20-6, "We maintain a global rate of 90 requests/60s and a burst of 6";

    @done = ();
}
