# $Id$
use ExtUtils::MakeMaker;
	
my $script = 'perlbrowser';

WriteMakefile(
    'NAME'		    => $script,
	'VERSION'       => '0.12',
	
	'EXE_FILES' =>  [ $script ],
	    	
	'PREREQ_PM' => {
		'Test::More'        => '0',
		},

	'MAN1PODS' => {
		$script => '$(INST_MAN1DIR)/$script.1',
		},
		
	clean => { FILES => "*.bak $script-*" },
	);
