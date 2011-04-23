use strict;
use warnings;

package WWW::Rietveld::API;

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
has title => ( is => 'ro', lazy_build => 1 );
has description => ( is => 'ro', lazy_build => 1 );

has email       => ( is => 'ro', isa      => 'Str', required   => 1 );
has password    => ( is => 'rw', isa      => 'Str', required   => 1 );
has token       => ( is => 'rw', required => 1,     lazy_build => 1 );
has auth_cookie => ( is => 'rw', required => 1,     lazy_build => 1 );

has ua         => ( is => 'ro', required => 1, lazy_build => 1 );
has cookiejar  => ( is => 'ro', required => 1, lazy_build => 1 );
has _issue_url => ( is => 'ro', required => 1, lazy_build => 1 );
has _http_response =>
    ( is => 'ro', isa => 'HTTP::Response', lazy_build => 1 );
has messages => ( is => 'ro', isa => 'ArrayRef' , lazy_build => 1);

sub _build_xsrftoken
{
    my $self = shift;

    # Parse xsrfToken from javascript VAR declaration.

    my $html = $self->_http_response->decoded_content();
    if ($html =~ m/
            x s r f Token # name of of token
            \s* = \s*     # 
            ['"]*         # might be quoted
            ( \w{32} )    # xrsfToken is a 32 word chars
            ['"]          # might be quoted
        /ix
        )
    {
        return $1;
    }

    $self->dprint( Dumper { html => $html } );
    die "xsrfToken parse failure";
}

sub _build_description
{
    my $self    = shift;
    my $scraper = scraper
    {
        process '//div[@id="issue-description"]', description => 'TEXT';
        result 'description';
    };
    my $res = $scraper->scrape( $self->_http_response );

    $self->dprint( Dumper { res => $res } );

    return $res;
}

sub _build_messages
{
    my $self = shift;

    my $scraper = scraper
    {
        process '@message', 'messages[]' => scraper
        {
            process 'div > table > tr > td';
            process 'tr.comment_title>td:first-of-type', author  => 'TEXT';
            #process 'tr > td + td',     comment => 'TEXT';
        };
        result 'messages';
    };
    $scraper = scraper 
    {
            process '@message > div > table > tr > td' , 'messages[]' => scraper
            {
                process '*', message => 'TEXT';
            };
            result 'messages';
    };
    $scraper = scraper 
    {
            process 'table.issue-details > tr > td > div#messages >div' , 'messages[]' => scraper
            {
                process 'div.header > table > tr > td', author => 'TEXT';
                process 'div.message-body > pre' , message => 'TEXT';
            };
            result 'messages';
    };
    my $res = $scraper->scrape( $self->_http_response );
    my @messages = grep { exists $_->{author} } @$res;

    #$self->dprint( Dumper { messages => \@messages } );
    return \@messages; 
}

sub is_lgtm
{
    my $self = shift;
    (   grep { /LGTM/i || /LTGM/i || /looks? good to me/i }
        map  { $_->{message} }
        grep { $_->{author} ne 'me' } 
        @{ $self->messages }
    ) ? 1 : 0;
}

sub _build_title
{
    my $self    = shift;
    my $title   = $self->_http_response->title;
#    my $scraper = scraper
#    {
#        process 'title', title => 'TEXT';
#    };
#    my $res = $scraper->scrape( $self->_http_response );
#    $self->dprint( Dumper { messages => $res } );
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
    die 'login failed : ' . $response->is_success
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
