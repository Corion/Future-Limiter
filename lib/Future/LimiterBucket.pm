package Future::LimiterBucket;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Carp qw(croak);

use Future::Limiter::Resource;
use Future::Limiter::Rate;

# Container for the defaults

has bucket_class => (
    is => 'ro',
);

has bucket_args => (
    is => 'ro',
    default => sub { {} },
);

has 'buckets' => (
    is => 'lazy',
    default => sub { {} },
);

sub _make_bucket( $self, %options ) {
    %options = (%{ $self->bucket_args() }, %options);
    $self->bucket_class->new( \%options );
}

sub _bucket( $self, $key ) {
    $key = '' unless defined $key;
    $self->buckets->{ $key } ||= $self->_make_bucket;
}

around 'BUILDARGS' => sub ( $orig, $class, @args ) {
    my %args;
    if( ref $args[0] ) {
        %args = ${ $args[0] }
    } else {
        %args = @args
    };
    my $bucket_class = delete $args{ bucket_class };
    if( $args{ maximum }) {
        $bucket_class ||= 'Future::Limiter::Resource';
    } elsif( $args{ rate }) {
        $bucket_class ||= 'Future::Limiter::Rate';
    } else {
        require Data::Dumper;
        croak "Don't know what to do with " . Data::Dumper::Dumper \%args;
    }
    $class->$orig( bucket_class => $bucket_class, bucket_args => \%args )
};

=head2 C<< $l->limit( $key ) >>

  my $token;
  $l->limit( $key )->then( sub {
      $token = @_;
      
      ... return another Future
  })->then(sub {
  
      # release the token to release our limiting
      undef $token
  })

=cut

sub limit( $self, $key = undef, @args ) {
    return $self->_bucket( $key )->limit( @args );

}
1;