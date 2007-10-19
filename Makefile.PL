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
        'Catalyst-Runtime' => 5.7,
        'Data::Pageset'    => 0,
        'Class::Accessor::Fast' => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CatalystX-CRUD-*' },
);
