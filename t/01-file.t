use Test::More tests => 3;

BEGIN {
    use lib qw( ../CatalystX-CRUD/lib );
    use_ok('CatalystX::CRUD::Model::File');
    use_ok('CatalystX::CRUD::Object::File');
}

use lib qw( t/lib );
use Catalyst::Test 'MyApp';
use Data::Dump qw( dump );

ok( get('/foo'), "get /foo" );

