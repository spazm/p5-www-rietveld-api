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
    debug    => 0,
);


like( $cr->xsrftoken, qr/^\w{32}$/, "xsrfToken is 32 chars long")
    or diag explain { xsrfToken => $cr->xsrftoken };

like( $cr->title, qr/Issue.*Code Review/, "title is correct format")
    or diag explain { title => $cr->title };

like( $cr->description, qr/lintall/i, "correct description for 6231173" )
    or diag explain { description => $cr->description };

my $messages = $cr->messages;
is( scalar @$messages, 7, "expected 7 messages from that page" )
    or diag explain { test_messages => $cr->messages };

ok( $cr->is_lgtm , "LGTMed");

#diag $cr->_http_response->decoded_content();

done_testing;
