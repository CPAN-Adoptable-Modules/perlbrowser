# $Id$
use ExtUtils::MakeMaker;
	
my $script = 'perlbrowser';

WriteMakefile(
    'NAME'		    => $script,
	'VERSION'       => '0.15',
	
	'EXE_FILES' =>  [ $script ],
	    	
	'PREREQ_PM' => {
		'Class::ISA'       => '0',
		'Devel::Symdump'   => '0',
		'File::Find::Rule' => '0',
		'IO::Scalar'       => '0',
		'Module::CoreList' => '0',
		'Module::ScanDeps' => '0',
		'Test::File'       => '0',
		'Test::More'       => '0',
		'Tk::CodeText'     => '0',
		'Tk::HList'        => '0',
		'Tk::NoteBook'     => '0',
		'Tk'               => '0',
		},

	'MAN1PODS' => {
		$script => "\$(INST_MAN1DIR)/$script.1",
		},
		
	clean => { FILES => "*.bak $script-*" },
	);
