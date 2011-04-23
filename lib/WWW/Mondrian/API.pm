use strict;
use warnings;

package WWW::Mondrian::API;

use Data::Dumper;
use HTTP::Cookies;
use HTTP::Request;
use LWP;
use Moose;
use Web::Scraper;

has protocol => ( is => 'ro', default => 'http', required => 1 );
has domain   => ( is => 'ro', isa     => 'Str',  required => 1 );
has issue => ( is => 'ro', isa => 'Str', required => 1, lazy_build => 1 );
has xsrftoken => ( is => 'ro', isa => 'Str', required => 1, lazy_build => 1 );
has debug => ( is => 'rw', isa => 'Str', default => '0' );

has email       => ( is => 'ro', isa      => 'Str', required   => 1 );
has password    => ( is => 'rw', isa      => 'Str', required   => 1 );
has token       => ( is => 'rw', required => 1,     lazy_build => 1 );
has auth_cookie => ( is => 'rw', required => 1,     lazy_build => 1 );

has ua         => ( is => 'ro', required => 1, lazy_build => 1 );
has cookiejar  => ( is => 'ro', required => 1, lazy_build => 1 );
has _issue_url => ( is => 'ro', required => 1, lazy_build => 1 );
has _http_response =>
    ( is => 'ro', isa => 'HTTP::Response', lazy_build => 1 );
has messages => ( is => 'ro', isa => 'ArrayRef' );

sub _build_xsrftoken
{
    my $self = shift;

    my $html = $self->_http_response->decode_content();
    if ($html =~ m/
            xrsfToken 
            \s* = \s*     
            ['"]*         # might be quoted
            ( \w{32} )    # xrsfToken is a 32 word chars
            ['"]          # might be quoted
        /ix
        )
    {
        return $1;
    }

    $self->dprint( { html => $html } );
    die "xsrfToken parse failure";
}

sub _build_description
{
    my $self    = shift;
    my $scraper = scraper
    {
        process 'id(issue-description)', description => 'TEXT';
    };
    my $res = $scraper->scrape( $self->_http_response );

    $self->dprint( Dumper { res => $res } );

    return $res->{description};
}

sub _build_messages
{
    my $self = shift;

    my $scraper = scraper
    {
        process '@message', 'messages[]' => scraper
        {
            process 'tr(comment-title)>td', author  => 'TEXT';
            process 'id(cl-message-1)',     comment => 'TEXT';
        };
        result 'messages';
    };
    my $res = $scraper->scrape( $self->_http_response );
    $self->dprint( Dumper { messages => $res } );
}

sub _build_title
{
    my $self    = shift;
    my $scraper = scraper
    {
        process 'title', title => 'TEXT';
    };
    my $res = $scraper->scrape( $self->_http_response );
    $self->dprint( Dumper { messages => $res } );
}

sub _build__http_response
{
    my $self = shift;
    my $ua   = $self->ua;
    my $url  = $self->_issue_url;

#    my $auth_header = { 'Authorization' => 'GoogleLogin auth=' . $self->token };
#my $response = $ua->get($url, %$auth_header );
    my $response = $ua->get($url);

    die sprintf( "Fetch failed: %s , %s\n",
        $response->is_success, $response->status_line )
        unless $response->is_success;

    return $response;
}

sub authenticate
{
    my $self = shift;
    return $self->token ? 1 : 0;
}

sub _build_token
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
    die "login failed : $response->is_success"
        unless defined $token;

    return $token;
}

sub _build_auth_cookie
{
    my $self = shift;
    my $ua   = $self->ua;
    my $continue_location
        = "http://localhost/";    #dummy location so we know we succeeded.
    my $args = [ 'continue' => $continue_location, 'auth' => $self->token ];
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

    #$url, $args );
    $self->dprint( Dumper { auth_cookie_response => $response } );
    $ua->max_redirect($max_redirect);

#    my $auth_header = { 'Authorization' => 'GoogleLogin auth=' . $self->token };

}

sub _build__issue_url
{
    my $self = shift;
    my $str  = sprintf "%s://%s/%d/",
        $self->protocol,
        $self->domain,
        $self->issue;
    $self->dprint( Dumper { issue_url => $str } );

    return $str;
}

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
        file     => "$ENV{HOME}/.cookies.txt",
        autosave => 1,
    );
}

sub dprint
{
    my $self = shift;
    return unless $self->debug;
    print STDERR @_, "\n";
}

#SYNOPSIS: Provide an API to Mondrian/Rietveld code review system, by parsing html.

1;
