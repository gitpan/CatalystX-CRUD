#!perl -T

use Test::More tests => 9;

BEGIN {
	use_ok( 'CatalystX::CRUD' );
        use_ok( 'CatalystX::CRUD::Model' );
        use_ok( 'CatalystX::CRUD::Controller' );
        use_ok( 'CatalystX::CRUD::REST' );
        use_ok( 'CatalystX::CRUD::Object' );
        use_ok( 'CatalystX::CRUD::Iterator' );
        use_ok( 'CatalystX::CRUD::Model::File' );
        use_ok( 'CatalystX::CRUD::Object::File' );
        use_ok( 'CatalystX::CRUD::Iterator::File' );
}

diag( "Testing CatalystX::CRUD $CatalystX::CRUD::VERSION, Perl $], $^X" );
