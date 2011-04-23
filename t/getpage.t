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

diag explain $cr->_http_response;

done_testing;
