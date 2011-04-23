use strict;
use warnings;

use Test::More;
use WWW::Mondrian::API;
use Data::Dumper;

my $cr = WWW::Mondrian::API->new(
    domain   => 'code.open42.com',
    issue    => '6231173',
    email    => 'user@open42.com',
    password => 'password',
    debug    => 1,
);

my $expected_issue_url = 'http://code.open42.com/6231173/';

isa_ok( $cr, 'WWW::Mondrian::API' );
ok( defined $cr->token, "login token defined" )
    or diag explain { token => $cr->token() };

ok( $cr->authenticate, 'authenticated' );
diag "authenticated";

is( $cr->_issue_url(), $expected_issue_url, 'issue_url' );
    or diag Dumper { '_issue_url' => $cr->_issue_url };

diag explain $cr->auth_cookie;

done_testing;
