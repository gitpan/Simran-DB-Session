use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Simran::DB::Session',
    'VERSION_FROM' => 'Session.pm', # finds $VERSION
    'PREREQ_PM' => { 
        'Carp' => 0,  
        'Simran::Error::Error' => 0, 
    },
);

