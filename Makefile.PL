use ExtUtils::MakeMaker;

%mods = ( 'Curses'	=> '0');

WriteMakefile(
    'NAME'	=> 'Curses::Widgets',
    'VERSION' => '0.8',
	'PREREQ_PM'	=> \%mods
);
