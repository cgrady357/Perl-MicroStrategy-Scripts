use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Business::Intelligence::MicroStrategy::CommandManager::NCS',
    AUTHOR              => q{Craig Grady <cgrady357@gmail.com>},
    VERSION_FROM        => 'lib/Business/Intelligence/MicroStrategy/CommandManager/NCS.pm',
    ABSTRACT_FROM       => 'lib/Business/Intelligence/MicroStrategy/CommandManager/NCS.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Business-Intelligence-MicroStrategy-CommandManager-NCS-*' },
);
