use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CatalystX::CRUD',
    AUTHOR              => 'Peter Karman <perl@peknet.com>',
    VERSION_FROM        => 'lib/CatalystX/CRUD.pm',
    ABSTRACT_FROM       => 'lib/CatalystX/CRUD.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Data::Pageset'    => 0,
        'Class::Accessor::Fast' => 0,
        'Catalyst::Component::ACCEPT_CONTEXT' => 0,
        'Catalyst::Runtime'     => 0,
        'Catalyst::Exception'   => 0,
        'Path::Class::File'     => 0,
        'NEXT'                  => 0,
        'Data::Dump'            => 0,  # for testing


    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CatalystX-CRUD-*' },
);