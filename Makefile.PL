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
        'Class::C3'             => 0,
        'Data::Dump'            => 0,  # for testing
        'Sort::SQL'             => 0.03,
        'Search::QueryParser::SQL' => 0.005,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CatalystX-CRUD-*' },
);
