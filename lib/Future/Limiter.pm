package Future::Limiter;
use strict;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use YAML qw(LoadFile);
use Future;
use Future::Limiter::LimiterChain;

our $VERSION = '0.01';

with 'Future::Limiter::Role';

use Future::Limiter::Resource;
use Future::Limiter::Rate;

=head1 NAME

Future::Limiter - impose rate and resource limits

=head1 SYNOPSIS

  my $l = Future::Limiter->from_yaml(<<'YAML');
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

  my ($host_token, $rate_token);
  $limiter->limit( 'request', $hostname, $url )->then(sub {
      my ($host_token, $url ) = @_;
      request_url( $url )->on_ready( undef $host_token );
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

has limits => (
    is => 'ro',
    default => sub { {} },
);

sub _generate_limiters( $class, $config ) {
    my %limiters = map {
        $_ => Future::Limiter::LimiterChain->new( $config->{$_} )
    } sort keys %$config;

    $class->new({
        limits => \%limiters
    })
}

=head1 METHODS

=cut

sub from_file( $class, $filename ) {
    my $spec = LoadFile $filename;
    $class->from_config( $spec )
}

sub from_yaml( $class, $yaml ) {
    my $spec = Load $yaml;
    $class->from_config( $spec )
}

sub from_config( $class, $config ) {
    $class->_generate_limiters( $config )
}

=head2 C<< $limiter->limit( $eventname, $eventkey, @args ) >>

    my ($token,@args) = await $limiter->limit('fetch',$url->hostname);
    ... do work
    undef $token; # release token

    $limiter->limit('fetch',$url->hostname,$url)->then(sub( $token, $url) {
        return http_request($url)->on_ready(sub { undef $token });
    };

The method to rate-limit an event from occurring, by key. The key can be
C<undef> to mean a global limit on the event.

The method returns a future that will return a token to release the current
limit and the arguments passed in.

=cut

sub limit($self, $eventname, $eventkey=undef, @args) {
    if( my $limiter = $self->limits->{$eventname}) {
        return $limiter->limit( $eventkey, @args )
    } else {
        return Future->done( [], @args )
    }
};

sub visualize( $self ) {
    return [
        map {
        {
          name       => $_,
          high_water => 0,
          next       => 0,
          backlog    => 0,
          # submission frequency?
          # completion frequency?
        },
        } sort keys %{$self->limiters}
    ],
}

1;

=head1 TODO

Persistence of the rate limiter, or periodical writeback of the current limits
to a shared file / scoreboard to allow for cross-process limiting

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

Copyright 2018-2019 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
