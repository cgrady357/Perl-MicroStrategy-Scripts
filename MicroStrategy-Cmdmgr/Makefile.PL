use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MicroStrategy::Cmdmgr',
    AUTHOR              => 'Craig Grady <cgrady357@gmail.com>',
    VERSION_FROM        => 'lib/MicroStrategy/Cmdmgr.pm',
    ABSTRACT_FROM       => 'lib/MicroStrategy/Cmdmgr.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'zip -9f', SUFFIX => 'zip', },
    clean               => { FILES => 'MicroStrategy-Cmdmgr-*' },
);
