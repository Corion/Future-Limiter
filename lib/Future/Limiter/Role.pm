package Future::Limiter::Role;
use Moo::Role;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Future::Scheduler;

has 'scheduler' => (
    is => 'lazy',
    default => sub { Future::Scheduler->new() }
);

sub future( $self ) {
    $self->scheduler->future()
}

sub sleep( $self, $seconds = 0 ) {
    $self->scheduler->sleep($seconds)
}

sub schedule( $self, $f, $args=[], $seconds = 0 ) {
    # This is backend-specific and should put a timeout
    # after 0 ms into the queue or however the IO loop schedules
    # an immediate callback from the IO loop
    my $n;
    $n = $self->sleep($seconds)->then(sub { undef $n; $f->done( @$args ) });
    $n
}

sub limit( $self, $key=undef, @args ) {
    my $token = undef;
    my $res = $self->future;
    push @{ $self->queue }, [ $res, $token, \@args ];
    $self->schedule_queued;
    $res;
}

1;

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
