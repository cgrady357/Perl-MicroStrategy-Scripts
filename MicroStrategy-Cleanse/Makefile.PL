use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MicroStrategy::Cleanse',
    AUTHOR              => 'Craig Grady <cgrady357@gmail.com>',
    VERSION_FROM        => 'lib/MicroStrategy/Cleanse.pm',
    ABSTRACT_FROM       => 'lib/MicroStrategy/Cleanse.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MicroStrategy-Cleanse-*' },
);
