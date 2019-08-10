package Future::Limiter::LimiterChain;
use strict;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use Carp qw( croak );
use Future::LimiterBucket;

our $VERSION = '0.01';

=head1 NAME

Future::Limiter::LimiterChain - limit by maximum concurrent, rate

=head1 SYNOPSIS

    my $l = Future::LimiterChain->from_yaml(<<'YAML');
        request:
            # Make no more than 1 request per second
            # have no more than 4 requests in flight at a time
            # If there is a backlog, process them as quickly as possible
            - burst : 3
            rate : 60/60
            - maximum: 4
        namelookup:
            - burst : 3
            rate : 60/60
    YAML
    
    ...
    
    push @jobs, Future->done($i)->then(sub($id) {
        $l->limit('request', undef, $id )
    })->then(sub {
        my ($token,$id) = @_;
        return perform_work_as_future($id, $token);
    });

    # Wait for all jobs to finish, while avoiding hitting them with bursts
    # of more than 3 requests and a rate of 60 requests/s.
    my @res = Future->wait_all(@jobs)->get();

=head1 METHODS

=cut

sub new( $class, $limits ) {
    my @chain;
    for my $l (@$limits) {
        if( exists $l->{maximum}) {
            push @chain, Future::LimiterBucket->new( %$l );
        } elsif( exists $l->{burst} ) {
            $l->{ rate } =~ m!(\d+)\s*/\s*(\d+)!
                or croak "Invalid rate limit: $l->{rate}";
            $l->{rate} = $1 / $2;
            push @chain, Future::LimiterBucket->new( rate => $l->{rate}, burst => $l->{burst}, );
        } else {
            require Data::Dumper;
            croak "Don't know what to do with " . Data::Dumper::Dumper $limits;
        }
    }

    bless { chain => \@chain } => $class;
}
sub chain( $self ) { $self->{chain} }

sub limit( $self, $key=undef, @args ) {
    my $f = Future->wait_all(
        map { $_->limit( $key, @args ) } @{ $self->chain }
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