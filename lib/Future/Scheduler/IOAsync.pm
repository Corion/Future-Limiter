package Future::Scheduler::IOAsync;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use IO::Async::Loop;
use IO::Async::Future;

has loop => (
    is => 'lazy',
    default => sub { IO::Async::Loop->new },
);

sub future( $self ) {
    $self->loop->future
}

=head2 C<< $sched->sleep( $seconds ) >>

    $sched->sleep( 10 )->get; # wait for 10 seconds

Returns a Future that will be resolved in the number of seconds given.

=cut

sub sleep( $self, $seconds = 0 ) {
    return $self->loop->delay_future( after => $seconds )
}

sub schedule( $self ) {
    return $self->sleep(0)
}

1;