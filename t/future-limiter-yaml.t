#!perl -w
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Test::More;

BEGIN {
    my $ok = eval {
        require AnyEvent::Future;
        1;
    };

    if( ! $ok) {
        plan skip_all => $@;
        exit;
    };
    plan tests => 18;
};

use YAML qw(LoadFile);
use Future::LimiterBucket;
use Future::Limiter;
use Future::Limiter::Chain;
use Future::IO;

use Data::Dumper;

my $limit = Future::Limiter->from_file( 't/ratelimits.yml' );

ok exists $limit->limits->{namelookup}, "We have a limiter named 'namelookup'";
ok exists $limit->limits->{request}, "We have a limiter named 'request'";

# Now check that we take the time we like:
# 10 requests at 1/s with a burst of 3, and a duration of 4/req should take
# 3@0 , 1@1, 3@4, 1@5
# finishing times
# 3@4 , 1@5  3@8, 1@9

sub work($time, $id) {
    Future::IO->sleep( $time )->on_ready(sub {
        #warn "Timer expired";
    })->catch(sub{warn "Uhoh @_"})->then(sub{ Future->done($id)});
}

# This approach requires that all sections we use will always be available
# in the config file. This is unlikely. Also, we don't get a good way for
# insights into the latency or min / max throughput

my (@jobs, @done);
my $start = time;
for my $i (1..10) {
    push @jobs, Future->done($i)->then(sub($id) {
        $limit->limit('request',undef, $i)
    })->then(sub($token,$id,@r) {
        ok ref $token, "We get a token passed from the limiter, and it's a ref";
        work(4, $id);
    })->then(sub($id,@r) {
        push @done, [time-$start,$id];
        Future->done
    })->catch(sub{
        warn "@_ / $! / $_";
    });
}
# Wait for the jobs
my @res = Future->wait_all(@jobs)->get();

is 0+@done, 10, "10 jobs completed";
my $first = $done[0]->[0];
is $done[0]->[0], $first, "Burst";
is $done[1]->[0], $first, "Burst";
is $done[2]->[0], $first, "Burst";
is $done[3]->[0], $first+1, "Rate/maximum";
is $done[4]->[0], $first+4, "Rate/maximum";
