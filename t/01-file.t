use Test::More tests => 6;

BEGIN {
    use lib qw( ../CatalystX-CRUD/lib );
    use_ok('CatalystX::CRUD::Model::File');
    use_ok('CatalystX::CRUD::Object::File');
}

use lib qw( t/lib );
use Catalyst::Test 'MyApp';
use Data::Dump qw( dump );

ok( get('/foo'), "get /foo" );

ok( my $response = request('/file/search'), "response for /file/search" );

#dump( $response->headers );

is( $response->headers->{status}, '302', "response was redirect" );

ok( get('/autoload'), "get /autoload" );

