package Future::Limiter::Resource;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use AnyEvent::Future; # later we'll go independent
use Scalar::Util qw(weaken);
use Guard 'guard';

with 'Future::Limiter::Role'; # limit()

our $VERSION = '0.01';

has maximum => (
    is => 'rw',
    default => 4,
);

has active_count => (
    is => 'rw',
    default => 0,
);

# The callback that gets executed when ->maximum+1 is reached
has on_highwater => (
    is => 'rw',
);

has queue => (
    is => 'lazy',
    default => sub { [] },
);

# For a semaphore-style lock
sub get_release_token( $self ) {
    # Returns a token for housekeeping
    # The housekeeping callback may or may not trigger more futures
    # to be executed
    my $token_released = guard {
        #warn "Reducing active count to $c";
        $self->remove_active();
        # scan the queue and execute the next future
        if( @{ $self->queue }) {
            $self->schedule_queued;
        };
    };
}

sub add_active( $self ) {
    if( $self->active_count < $self->maximum ) {
        $self->active_count( $self->active_count+1 );
        return $self->future->done($self->get_release_token);
    } else {
        # ?! How will this ever kick off?!
        return $self->future->new();
    }
}

sub remove_active( $self ) {
    if( $self->active_count > 0 ) {
        $self->active_count( $self->active_count-1 );
    };
}

=head2 C<< $bucket->enqueue( $cb, $args ) >>

  my $f = $bucket->enqueue(sub {
      my( $token, @args ) = @_;
      ...
  }, '1');

Enqueues a callback and returns a future. The callback will be passed a token
as the first parameter. Releasing that token will release the locks that the
future holds.

=cut

=head2 C<< $bucket->schedule_queued >>

  $bucket->schedule_queued

Processes all futures that can be started while obeying the current rate limits.

=cut

sub schedule_queued( $self ) {
    my $queue = $self->queue;
    while( @$queue and $self->active_count < $self->maximum ) {
        #warn sprintf "Dispatching (act/max %d/%d)", $self->active_count, $self->maximum;
        my( $f, $args ) = @{ shift @$queue };
        # But ->schedule doesn't increase ->active_count, does it?!
        my $n;
        $n = $self->add_active;
        my $res; $res = $n->then(sub( $token, @args ) {
            undef $res;
            $f->done( $token, @$args )
        });
    };
    if( 0+@$queue ) {
        # We have some more to launch but reached our concurrency limit
        # the active futures will call us again in their ->on_done()
    };
}

1;

=head1 SEE ALSO

L<Future::Mutex>

=head1 REPOSITORY

The public repository of this module is
L<http://github.com/Corion/Future-Limiter>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Future-Limiter>
or via mail to L<future-limiter-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2018 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
