package Future::Limiter;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Carp qw(croak);

with 'Future::Limiter::Role';

our $VERSION = '0.01';

use Future::Limiter::Resource;
use Future::Limiter::Rate;

=head1 NAME

Future::Limiter - impose rate and resource limits

=head1 SYNOPSIS

  # max 4 requests (per host)
  my $concurrency = Future::Limiter->new(
      maximum => 4
  );

  # rate of 30 per minute
  my $rate = Future::Limiter->new(
      rate  => 0.5,
      burst => 2,
  );

  my ($host_token, $rate_token);
  $concurrency->limit( $hostname, $url )->then(sub {
      ($host_token, my $url ) = @_;
  })->then( sub {
      $rate->limit( $hostname, $url )
  })->then( sub {
      ( $rate_token, my $url ) = @_;
      request_url( $url )
  })->then(sub {
      ...
      undef $host_token;
      undef $rate_token;
  });

This module provides an API to handle rate limits and resource limits in a
unified API.

=head2 Usage with Future::AsyncAwait

The usage with L<Future::AsyncAwait> is much more elegant, as you only need
to keep the token around and other parameters live implicitly in your scope:

  my( $host_token ) = await $concurrency->limit( $hostname );
  my( $rate_token ) = await $rate->limit( $hostname );
  request_url( $url )
  ...

=cut

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
    $options{ scheduler } ||= $self->scheduler;
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
    if( exists $args{ maximum }) {
        $bucket_class ||= 'Future::Limiter::Resource';
    } elsif( exists $args{ rate } or exists $args{ burst }) {
        $bucket_class ||= 'Future::Limiter::Rate';
    } else {
        require Data::Dumper;
        croak "Don't know what to do with " . Data::Dumper::Dumper \%args;
    }
    $class->$orig( bucket_class => $bucket_class, bucket_args => \%args )
};

=head2 C<< $l->limit( $key, @args ) >>

  my $token;
  $l->limit( $key )->then( sub {
      $token = @_;
      
      ... return another Future
  })->then(sub {
  
      # release the token to release our limiting
      undef $token
  })

This method returns a L<Future> that will become fulfilled if the current
limit is not reached. The C<$key> parameter restricts that resource to a
specific key (like, a hostname).

The future returns a token that must be released for the resource to be freed
again. Additional parameters are passed through as well.

=cut

sub limit( $self, $key = undef, @args ) {
    return $self->_bucket( $key )->limit( @args );
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
