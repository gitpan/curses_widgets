use ExtUtils::MakeMaker;

%mods = ( 'Curses'	=> '0');

WriteMakefile(
    'NAME'	=> 'Curses::Widgets',
    'VERSION' => '1.0',
	'PREREQ_PM'	=> \%mods
);
