require 5.008;
use strict;
use warnings;
	

my $script = 'perlbrowser';

my $github    = 'https://github.com/briandfoy/perlbrowser';
my $main_file = 'lib/App/perlbrowser.pm';

my %WriteMakefile = (
    'NAME'		    => $script,
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'  => $main_file,
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',
	
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

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			//
		"$MM 6.64";
	eval "use $MM_version" || die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
