package Future::Scheduler::Future;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use IO::Async::Loop;
use IO::Async::Future;

sub future( $self ) {
    Future->new
}

=head2 C<< $sched->sleep( $seconds ) >>

    $sched->sleep( 10 )->get; # wait for 10 seconds

Returns a Future that will be resolved in the number of seconds given.

=cut

sub sleep( $self, $seconds = 0 ) {
    sleep $seconds;
    return Future->done();
}

sub schedule( $self ) {
    return $self->sleep(0)
}

1;