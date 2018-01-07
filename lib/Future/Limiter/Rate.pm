package Future::Limiter::Rate;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use AnyEvent::Future; # later we'll go independent
use Scalar::Util qw(weaken);
use Guard 'guard';
use Algorithm::TokenBucket;

with 'Future::Limiter::Role'; # ->limit(), ->schedule()

our $VERSION = '0.01';

has burst => (
    is => 'ro',
    default => 5,
);

has rate => (
    is => 'ro',
    default => 1,
);

has bucket => (
    is => 'lazy',
    default => sub( $self ) { Algorithm::TokenBucket->new( $self->{ rate }, $self->{ burst }, $self->{ burst }) },
);

has queue => (
    is => 'lazy',
    default => sub { [] },
);

# The future that will be used to ->sleep()
has next_token_available => (
    is => 'rw',
);

sub get_release_token( $self ) {
    # Returns a token for housekeeping
    # The housekeeping callback may or may not trigger more futures
    # to be executed
    my $token_released = guard {
        #warn "Reducing active count to $c";
        $self->remove_active();
        # scan the queue and execute the next future
        if( my $next = shift @{ $self->queue }) {
            my $t; $t = $self->add_active();
            $t->then(sub( $token ) {
                undef $t;
                $next->done( $token );
            });
        };
    };
}

sub add_active( $self ) {
    if( $self->active_count < $self->maximum ) {
        $self->active_count( $self->active_count+1 );
        return $self->future->done($self->get_release_token);
    } else {
        return $self->future->new();
    }
}

sub remove_active( $self ) {
    if( $self->active_count > 0 ) {
        $self->active_count( $self->active_count-1 );
    };
}

=head2 C<< $bucket->schedule_queued >>

  $bucket->schedule_queued

Processes all futures that can be started while obeying the current rate limits
(including burst).
  
=cut

sub schedule_queued( $self ) {
    my $bucket = $self->bucket;
    my $queue = $self->queue;
    while( @$queue and $bucket->conform(1)) {
        my( $f, $args, $token ) = @{ shift @$queue };
        $bucket->count(1);
        $self->schedule( $f, [$args, $token] );
    };
    if( 0+@$queue ) {
        # We have some more to launch but reached our rate limit
        # so we now schedule a callback to ourselves (if we haven't already)
        if( ! $self->next_token_available ) {
            my $earliest_time = $bucket->until(1);
            my $s = $self;
            weaken $s;
            #warn "Setting up cb after $earliest_time";
            my $wakeup;
            $wakeup = $self->sleep($earliest_time)->then(sub{
                $wakeup->set_label('wakeup call');
                # Remove this callback:
                $self->next_token_available(undef);
                $s->schedule_queued();
                Future->done()
            })->catch( sub {
                use Data::Dumper;
                warn "Caught error: $@";
                warn Dumper \@_;
            });
            $self->next_token_available($wakeup);
        };
    };
}

1;

=head1 SEE ALSO

L<Algorithm::TokenBucket>

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
