package Future::Limiter::LimiterChain;
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