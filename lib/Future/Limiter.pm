package Future::Limiter;
use Moo 2;
use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';
use YAML qw(LoadFile);
use Future;
use Future::Limiter::LimiterChain;

=head1 NAME

Future::Limiter - rate limter for your application

=head1 SYNOPSIS

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

=cut