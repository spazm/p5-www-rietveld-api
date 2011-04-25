package UnitTest::WWW::Rietveld::Auth;
use Moose;
use Data::Dumper;

has email     => ( is => 'ro', );
has password  => ( is => 'ro', );
has domain    => ( is => 'ro', );
has protocol  => ( is => 'ro', default => 'http' );
has ua        => ( is => 'ro', lazy_build => 1 );
has cookiejar => ( is => 'ro', lazy_build => 1 );

sub dprint {
    #print STDERR Dumper \@_;
};

sub _build_ua
{
    my $self = shift;
    my $ua = LWP::UserAgent->new( cookie_jar => $self->cookiejar );

    return $ua;
}

sub _build_cookiejar
{
    my $self = shift;
    return HTTP::Cookies->new(
#        file     => "$ENV{HOME}/.cookies.txt",
#        autosave => 1,
    );
}


with 'WWW::Rietveld::Role::Auth';

package main;
use strict;
use warnings;

use Test::More;
use Data::Dumper;

my $auth = UnitTest::WWW::Rietveld::Auth->new(
    email    => 'user@example.com',
    password => 'password',
    domain   => 'code.example.com',
);

diag explain { is_auth_valid => $auth->is_auth_valid() };

SKIP:
{
    skip "already logged in" ,4  if $auth->is_auth_valid;

    isa_ok( $auth, 'UnitTest::WWW::Rietveld::Auth' );
    my $token = eval { $auth->auth_token };
    ok( defined $token, "login token defined" )
        or diag explain { token => $token, error => $@ };

    my $renew        = eval { $auth->_renew_auth_cookie };
    ok( $renew, "renew auth cookie" )
        or diag explain { renew => $renew, error => $@ };

    my $authenticate = eval { $auth->authenticate };
    ok( $authenticate, "authenticate succeeds" )
        or diag explain { authenticate => $authenticate, error => $@ };
}


done_testing;
