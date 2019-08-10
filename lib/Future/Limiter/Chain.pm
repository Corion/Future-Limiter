package Future::Limiter::Chain;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Carp qw( croak );
use Future::Limiter;

our $VERSION = '0.01';

=head1 NAME

Future::Limiter::Chain - combine limiters

=head1 SYNOPSIS

  my $chain = Future::Limiter::Chain->from_config([
    # we want 4 active at the same time
    { maximum => 4 },
    # but then slow these to a rate of 2 per second
    { burst => 3, rate => "2/1" },
  ]);

  my $chain = Future::Limiter::Chain->new([
    # we want 4 active at the same time
    { maximum => 4 },
    # but then slow these to a rate of 2 per second
    { burst => 3, rate => 120/60 },
  ]);

=cut

with 'Future::Limiter::Role';

has chain => (
    is => 'lazy',
    default => sub {[]},
);

sub from_config( $class, $config ) {
    my @chain;

    for my $l (@$config) {
        if( exists $l->{maximum}) {
            push @chain, Future::Limiter->new( %$l );
        } elsif( exists $l->{burst} or exists $l->{rate}) {
            if( $l->{ rate } =~ m!(\d+)\s*/\s*(\d+)! ) {
                $l->{rate} = $1 / $2;
            }
            push @chain, Future::Limiter->new( rate => $l->{rate}, burst => $l->{burst}, );
        } else {
            require Data::Dumper;
            croak "Don't know what to do with " . Data::Dumper::Dumper $config;
        }
    }
        
    $class->new( chain => \@chain )
}

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
