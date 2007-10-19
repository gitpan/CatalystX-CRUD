#!perl -T

use Test::More tests => 5;

BEGIN {
	use_ok( 'CatalystX::CRUD' );
        use_ok( 'CatalystX::CRUD::Model' );
        use_ok( 'CatalystX::CRUD::Controller' );
        use_ok( 'CatalystX::CRUD::Object' );
        use_ok( 'CatalystX::CRUD::Iterator' );
}

diag( "Testing CatalystX::CRUD $CatalystX::CRUD::VERSION, Perl $], $^X" );
