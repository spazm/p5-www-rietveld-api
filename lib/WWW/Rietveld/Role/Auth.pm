use strict;
use warnings;

package WWW::Rietveld::Role::Auth;

#SYNOPSIS: Provide Authentication cookie for google app service via 2-stage auth.

use Data::Dumper;
use HTTP::Cookies;
use HTTP::Request;
use LWP;
use Moose::Role;
use Web::Scraper;

requires(
    qw(
        email
        password

        protocol
        domain

        ua

        dprint
        )
);
has auth_token       => ( is => 'rw', required => 1,     lazy_build => 1 );


sub authenticate
{
    my $self = shift;
    return 1 if $self->is_auth_valid();
    return 1 if $self->_renew_auth_cookie();
    return 0;
}

sub is_auth_valid
{
    my $self = shift;

    my $url = sprintf '%s://%s/', $self->protocol, $self->domain;
    my $ua  = $self->ua();

    my $max_redirect = $ua->max_redirect;
    $ua->max_redirect(0);
    my $response = $self->ua->get( $url );
    $ua->max_redirect($max_redirect);
    $self->dprint(  Dumper { url => $url, code => $response->code } );
    #$self->dprint( Dumper { is_auth_valid_response => $response });
    return 0 if $response->code() == 302 ;
    return 1 if $response->code() == 200 ;
    return 0;
}

sub _renew_auth_cookie
{
    my $self = shift;
    my $ua   = $self->ua;
    my $continue_location
        = "http://localhost/";    #dummy location so we know we succeeded.
    my $args = [ 'continue' => $continue_location, 'auth' => $self->auth_token ];
    my $url = sprintf '%s://%s/_%s/login', $self->protocol, $self->domain,
        'ah';
    $self->dprint( Dumper { auth_cookie_args => $args, url => $url } );

    my $uri = URI->new($url);
    $uri->query_form($args);

    my $request = HTTP::Request->new( 'GET', $uri, );

    $self->dprint( Dumper { request => $request->as_string } );

    my $max_redirect = $ua->max_redirect;
    $ua->max_redirect(0);
    my $response = $ua->request($request);
    $self->dprint(
        Dumper { auth_cookie_response => $response, code => $response->code }
    );
    $ua->max_redirect($max_redirect);
    return $response->code() == 302 ? 1 : 0;
}

sub _build_auth_token
{
    my $self = shift;
    my $token;

    my $response = $self->ua->post(
        'https://www.google.com/accounts/ClientLogin',
        [   'accountType' => 'HOSTED',
            'service'     => 'ah',
            'source'      => 'rietveld-codereview-upload',
            'Email'       => $self->email,
            'Passwd'      => $self->password,
        ]
    );
    $self->dprint(
        Dumper {
            token_success => $response->is_success(),
            token_content => $response->content
        }
    );
    if ( $response->is_success )
    {
        foreach ( split( /\n/, $response->content() ) )
        {
            $token = $1 if /^Auth=(.+)$/;
            last if $token;
        }
    }
    die 'login failed : ' . $response->is_success
        unless defined $token;
    #TODO: catch login failures, bad password, captcha, etc.

    return $token;
}
1;
