use Test::More tests => 7 ;

use_ok('CatalystX::CRUD::Controller');
ok(my $controller = CatalystX::CRUD::Controller->new, "new controller");
is($controller->page_size, 50, 'default page_size');
ok($controller->page_size(10), "set page_size");
is($controller->page_size, 10, "get page_size");

{
    package MyC;
    @MyC::ISA = ( 'CatalystX::CRUD::Controller' );
    MyC->config( page_size => 30 );
}

ok( my $myc = MyC->new,  "new MyC");
is( $myc->page_size, 30, "set page_size in package config");



