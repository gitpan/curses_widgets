use ExtUtils::MakeMaker;

%mods = ( 'Curses'	=> '0');

WriteMakefile(
    'NAME'	=> 'Curses::Widgets',
	'AUTHOR' => 'Arthur Corliss <corliss@odinicfoundation.org>',
	'ABSTRACT' => 
	'High level access to widgets for rapid interface design.',
    'VERSION' => '1.2',
	'PREREQ_PM'	=> \%mods
);
