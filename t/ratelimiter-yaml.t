#!perl -w
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Test::More tests => 8;
use AnyEvent::Future;

use YAML qw(LoadFile);
use Future::Limiter;
use Future::Scheduler::Functions 'sleep', 'future';

use Data::Dumper;

sub generate_limiters( $blob ) {
    my %limiters = map {
        $_ => LimiterChain->new( $blob->{$_} )
    } sort keys %$blob;

    %limiters
}

sub from_file( $filename ) {
    my $spec = LoadFile $filename;
    generate_limiters( $spec )
}

my %limit = from_file( 't/ratelimits.yml' );

ok exists $limit{namelookup}, "We have a limiter named 'namelookup'";
ok exists $limit{request}, "We have a limiter named 'request'";

# Now check that we take the time we like:
# 10 requests at 1/s with a burst of 3, and a duration of 4/req should take
# 3@0 , 1@1, 3@4, 1@5
# finishing times
# 3@4 , 1@5  3@8, 1@9

sub work($time, $id) {
    sleep( $time )->on_ready(sub {
        #warn "Timer expired";
    })->catch(sub{warn "Uhoh @_"})->then(sub{ future()->done($id)});
}

# This approach requires that all sections we use will always be available
# in the config file. This is unlikely. Also, we don't get a good way for
# insights into the latency or min / max throughput

my (@jobs, @done);
my $start = time;
for my $i (1..10) {
    push @jobs, Future->done($i)->then(sub($id) {
        $limit{'request'}->limit(undef, $i)
    })->then(sub($token,$id,@r) {
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

package LimiterChain;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Carp qw( croak );
use Future::RateLimiter;
use Future::Limiter;

our $VERSION = '0.01';

sub new( $class, $limits ) {
    my @chain;
    for my $l (@$limits) {
        if( exists $l->{maximum}) {
            push @chain, Future::Limiter->new( %$l );
        } elsif( exists $l->{burst} ) {
            $l->{ rate } =~ m!(\d+)\s*/\s*(\d+)!
                or croak "Invalid rate limit: $l->{rate}";
            $l->{rate} = $1 / $2;
            push @chain, Future::Limiter->new( rate => $l->{rate}, burst => $l->{burst}, );
        } else {
            require Data::Dumper;
            croak "Don't know what to do with " . Data::Dumper::Dumper $limits;
        }
    }

    bless { chain => \@chain } => $class;
}
sub chain( $self ) { $self->{chain} }

sub limit( $self, @args ) {
    my $f = Future->wait_all(
        map { $_->limit( @args ) } @{ $self->chain }
    )->then( sub (@chain) {
        my @tokens;
        for my $f2 (@chain) {
            my( $other_token, @rest ) = $f2->get;
            push @tokens, $other_token;
        };
        Future->done( \@tokens, @args );
    });
    $f
}

1;