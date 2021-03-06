package App::perlbrowser;
use strict;
use warnings;

=encoding utf8

=head1 NAME

App::perlbrowser - a Tk class browser for Perl

=head1 SYNOPSIS

./perlbrowser

=head1 DESCRIPTION

This is a graphical Perl module explorer.  It is a Preview Release, meaning
that it is still very rough.  Not all things work, and some things may not
work correctly.

=head2 Features

You can select a module from the scrolling, hierarchial list on the
left.  Once you select a module, perlbrowser fetches information
about the module (in some cases from the network), and makes those
data available in several tabbed panes.

Many of the panes have widgets that look like you should be able
to type in them, but they are disabled.  You should still be able
to copy text from them, though.

Text panes have a Middle-Button menu that includes facilities for
searching within the pane and changing the syntax coloring rules.

=head3 Documentation pane

This pane displays the parsed POD for the selected module.
=head3 Code pane

This pane displays the syntax-colored raw code for the selected
module.

=head3 Meta-info pane

This pane shows selected meta-information about the module, including
CPAN data and local installation data.

=head3 Symbols pane

This pane shows, as much as it can, information about the module's
symbol table.

=head3 Core list pane

This pane shows the versions of the selected module which may
have been include in recent versions of perl.

=head3 ISA pane

This pane shows the inheritance tree for the selected module.

=head3 Prerequisites pane

This pane shows the prerequisite modules for the selected module.

=head3 Help pane

This pane shows the perlbrowser documentation.

=head2 Menus

=head3 File Menu

Nothing special here.  There is only a Quit entry.

=head3 Edit Menu

Nothing at all here.  Maybe there will be something later.

=head3 @INC Menu

The @INC menu has a list of checkbuttons for the directories
perlbrowser will scan for modules.  You can turn directories
on or off, clear the module list, or rescan the directories.
Rescanning the directories rebuilds the module list. Eventually
you will be able to add arbitrary directories.

=head3 Recent Menu

The Recent menu keeps track of the modules you have viewed.
Each time you view a module, perlbrowser adds it to the top
of the menu (removing it from elsewhere if appropriate), and
updates the accelerator keys for it.  You can recall the last
module you viewed with Control-1, the second-to-last with Control-2,
up to the tenth-to-last with Control-0.  You can also clear
the menu.  The perlbrowser application will save this list
and reload it the next time you start it.

=head3 Favorites Menu

You can add favorite modules to this menu for easy access. The
accelerator keys for this menu are currently broken.  The
perlbrowser application saves this list and reloads it the next
time you use perlbrowser.

=head2 Syntax Coloring

The text panes come from Tk::CodeText widgets.  You can adjust
the syntax rules with the ViewE<gt>Rules menu (Middle Button in
pane). The perlbrowser application will save your changes and use
them the next time it runs.  This still has some problems.



=head1 TO DO

=head1 For this version

=over 4

=item * info pane should clear inbetween modules (broken)

=item * stash inspector (Devel::Symdump, Module::Info, Symbol::Table?)

=item * ISA tree, with hot links (Class::ISA)

=item * dependencies, with hot links, remove corelist, group packages (Module::ScanDeps)

=item * get line numbering back (lost after using Tk::CodeText)

=item * if hlist active, jump to entries by typing ($hlist->see)

=item * add, remove directories to search

=item * fix copy export from text pane

=item * items in recent menu reposition hlist ($hlist->see)

=item * accelerators in favorites menu? (alt keypress digit)

=item * a lot of refactoring (maybe some internal packages to handle
things)

=back

=head1 For the next version

=over 4

=item * cache module list

=item * distro info (from network?)

=item * Search names with Regex, display matches in hlist

=item * tabs for several modules at once

=item * config file to set colors, etc

=item * link to other modules from module docs

=item * copying from source looks sort of like a patch file

=back

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	https://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy, E<lt>bdfoy@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright © 2003-2015, brian d foy <bdfoy@cpan.org>. All rights reserved.

You may use this program under the same terms as Perl itself.

=cut

use CPAN;
use Class::ISA;
use Data::Dumper;
use Devel::Symdump;
use File::Find::Rule;
use File::Basename;
use IO::Scalar;
use Module::CoreList;
use Module::ScanDeps;
use Pod::Text;
use Tk;
use Tk::CodeText;
use Tk::HList;
use Tk::NoteBook;

use vars qw( %Widgets %TextVariables %My_INC %Favorites @Module_tabs %Labels );

use constant DEBUG => $ENV{PB_DEBUG} || 0;

########################################################################
########################################################################
init();

my $mw = MainWindow->new();

mw_configure( $mw );
print "1\n";

make_gui( $mw );
print "2\n";

make_tabs();
print "3\n";
make_labels();
print "4\n";
make_version_labels();

create_hlist();
# prune auto split
my $inc = run_init();

add_help();

configure_hlist();

populate_hlist( $inc, $Widgets{'hlist'} );

MainLoop;

########################################################################
########################################################################
sub clear_recent
	{
	my $menu = $Widgets{'recent_menu'}->menu;

	my $last = $menu->index('last') - 2;

	foreach my $index ( reverse 0 .. $last )
		{
		$menu->delete( $index );
		}
	}

sub add_to_recent
	{
	my $package = shift;

	my %Seen = ();

	my $menu = $Widgets{'recent_menu'}->menu;

	my $last = $menu->index('last');

	if( $last > 10 ) { $menu->delete( $last - 2 ); }

	$menu->insert(
			0, 'command',
			-label => $package,
			-command => sub {
				display_module( $package );
				},
		);

	$last = $menu->index('last');

	my @pairs =	map {
			my $label = $menu->entrycget( $_, 'label' );
			if( ref $Seen{$label} )
				{
				push @{ $Seen{$label} }, $_;
				}
			else
				{
				$Seen{$label} = [ $_ ];
				}
			[ $_, $label ];
			} 0 .. $last - 2;

	my @deletes = sort { $b <=> $a } map {
		my $ref = $Seen{$_};
		if( @$ref == 1 ) { () }
		else             { @$ref[1..$#$ref]   }
		} keys %Seen;

	foreach my $index ( @deletes ) { $menu->delete( $index ); }

	update_recent_accelerators( $menu );

	$menu->update;
	}

sub update_recent_accelerators
	{
	update_menu_accelerators( $_[0], 'Control' );
	}

sub update_favorite_accelerators
	{
	update_menu_accelerators( $_[0], 'Alt' );
	}

sub update_menu_accelerators
	{
	my $menu = shift;
	my $meta = shift;

	my $last = $menu->index( 'last' );

	my %Symbols = qw(Control-Shift Shift- Control ^ Alt Alt-);
	my %Keys = qw(1 w 2 e 3 t 4 u 5 o 6 a 7 g 8 j 9 k 0 l);

	my $symbol = $Symbols{$meta};

	foreach my $index ( 0 .. $last - 2 )
		{
		my $package = $menu->entrycget( $index, 'label' );
		my $key     = ( $index + 1 ) % 10;

		$menu->entryconfigure(
			$index,
			-accelerator => "$symbol$key",
			);

		my $event = "<$meta-KeyPress-$key>";
		print "Event is $event\n" if DEBUG;

		$mw->bind( $event, '' );
		$mw->bind( 'all',  $event, sub { display_module( $package ) } );
		}

	$menu->update;
	$mw->update;
	}

sub add_favorite
	{
	my $package = shift;

	my $menu = $Widgets{'fav_menu'}->menu;

	# we must have been called from the menu
	unless( defined $package )
		{
		my $label = $menu->entrycget( 'last', 'label' );

		$label =~ m/^Add\s+(\S+)/g;

		$package = $1;
		}

	$menu->insert(
			0, 'command',
			-label => $package,
			-command => sub {
				display_module( $package );
				},
		);

	$Favorites{$package}++;

	update_add_favorite();

	$menu->update;
	}

sub update_add_favorite
	{
	my $package = shift;

	$package = undef if defined $package && exists $Favorites{$package};

	my $state = defined $package ? 'normal' : 'disabled';

	$package ||= 'favorite';

	my $menu = $Widgets{'fav_menu'}->menu;

	$menu->entryconfigure( 'last', -label => "Add $package",
		-state => $state, -command => sub { add_favorite( $package ) } );

	update_favorite_accelerators( $menu );

	$menu->update;
	}

sub make_gui
	{
	my $mw = shift;

	$Widgets{'top'}         = $mw->Frame->pack(
		-anchor => 'n', -expand => 1, -fill => 'both' );
	$Widgets{'bottom'}      = $mw->Frame->pack(
		-anchor => 'n', -expand => 1, -fill => 'none', -side => 'left' );

	$Widgets{'notebook'} = $Widgets{'top'}->NoteBook->pack(
		-anchor => 'n',
		-side   => 'right',
		-fill   => 'both',
		 );

	$Widgets{'sidebar' } = $Widgets{'top'}->Frame->pack(
		-anchor => 'n',
		-side   => 'left',
		-fill   => 'both' );

	$Widgets{'status'}   = $Widgets{'bottom'}->Label(
		-width => 80, -text => "Starting up..."
			)->pack(
				-side => 'left',
				-anchor => 'w',
				-expand => 1,
				-fill => 'none'
				);
	}

BEGIN {
@Module_tabs = (
	[ qw(pod Docs Pod)       ],
	[ qw(code Code Perl)     ],
	[ qw(meta Meta)          ],
	[ qw(symbol Symbols Pod) ],
	[ qw(core Core)          ],
	[ qw(isa ISA Pod)        ],
	[ qw(prereq Prereq Pod)  ],
	[ qw(help Help Pod)      ],
	);
	}

sub make_tabs
	{
	foreach my $ref ( @Module_tabs )
		{
		next unless UNIVERSAL::isa( $ref, 'ARRAY' );

		my $tab = $ref->[0] . "_tab";

		$Widgets{ $tab } = add_notebook_tab(
			$Widgets{'notebook'},
			$ref->[0],
			$ref->[1],
			);

		if( defined $ref->[2] )
			{
			my $name = $ref->[0];
			$Widgets{ $name } = text_widget(
				$Widgets{ $tab },
				$ref->[2],
				);
			}
		}
	}

sub create_hlist
	{
	$Widgets{'hlist'} = $Widgets{'sidebar'}->Scrolled( 'HList',
					-scrollbars       => 're',
					-height           => 25,
					-itemtype         => 'text',
					-highlightcolor   => 'green',
					-selectbackground => 'green',
					-separator        => '/',
					-selectmode       => 'single',
					)->pack(
						-anchor => 'w',
						-side   => 'left',
						-expand => 1,
						-fill   => 'both' );
	}

sub configure_hlist
	{
	$Widgets{'hlist'}->configure(
		-background => 'white',
		-command    => sub {
			unless( $_[0] =~ /\.p(?:m|od)\z/ )
				{
				my @kids = get_list_children( $_[0] );
				return unless @kids;

				$Widgets{'hlist'}->info('hidden', $kids[0]) ?
					expand_list( \@kids ) : shrink_list( \@kids );

				clear_module();
				}
			else
				{
				my $data = $Widgets{'hlist'}->info('data', $_[0]);

				my( $package, $file ) = split m/\000/, $data;

				display_module( $package, $file );
				}

			},
		);
	}

sub get_pod
	{
	my $file = shift;

	my $pod;
	my $p = Pod::Text->new;
	my $out = IO::Scalar->new( \$pod );

	my $in;
	open $in, $file;

	$p->parse_from_filehandle( $in, $out );

	return $pod;
	}

sub add_notebook_tab
	{
	my( $notebook, $title, $label ) = @_;

	$notebook->add( $title, -label => $label, -underline => 0 )
	}

sub print_status
	{
	my $message = shift;

	$Widgets{'status'}->configure( -text => $message );
	$Widgets{'status'}->update;

	print $message, "\n" if DEBUG;
	}

sub clear_status
	{
	$Widgets{'status'}->configure( -text => '' );
	$Widgets{'status'}->update;
	};

sub module_info
	{
	my $package = shift;
	my $hash = { map { $_, '???' } qw( inst_version cpan_version userid author) };

	$hash->{'package'} = $package;

	print_status( "Getting info for $package" );
	my $info = CPAN::Shell->expand('Module', $package);
	return $hash unless ref $info;

	$hash->{inst_version} = $info->inst_version;
	$hash->{cpan_version} = $info->cpan_version;
	$hash->{userid}       = $info->userid;
	$hash->{description}  = $info->description;
	$hash->{cpan_file}    = $info->cpan_file;
	$hash->{inst_file}    = $info->inst_file;

	$hash->{author}       = CPAN::Shell->expand('Author', $hash->{userid})->fullname;

	clear_status();

	return $hash;
	}

sub init
	{
	my $DATA_DIR = "$ENV{HOME}/.perlbrowser";
	mkdir $DATA_DIR unless -d $DATA_DIR;
	mkdir "$DATA_DIR/rules" unless -d "$DATA_DIR/rules";

	my $DATA_FILE = "$DATA_DIR/module_data";

	%My_INC = map { $_, 1 } @INC;

	my $hash;

	if( 0 and -e $DATA_FILE )
		{
		print_status( "Reading cached data..." );
		my $data = do { local $/; open FILE, $DATA_FILE; <FILE> };
		$hash = eval $data;
		return;
		}

	}

sub run_init
	{
	clear_status();

	load_favorites();
	load_recent();

	my $hash = get_modules();

	return $hash;
	}

sub clear_hlist
	{
	$Widgets{'hlist'}->delete( 'all' );
	}

sub make_hlist
	{
	my $hash = get_modules();

	clear_hlist( $Widgets{'hlist'} );

	populate_hlist( $hash, $Widgets{'hlist'} );
	}

sub get_modules
	{
	my $hash = {};

	my $rule = File::Find::Rule->new()->file->name( '*.pm' );

	my @search = grep { $My_INC{$_} } keys %My_INC;

	local( $") = "\n\t";
	print "Searching\n\t@search\n" if DEBUG;

	foreach my $dir ( @search )
		{
		print_status( "Processing $dir..." );
		my @files = map { s/\Q$dir\///; $_ } $rule->in( $dir );
		foreach my $path ( @files )
			{
			next if $path =~ m/^pods\b/;
			my $file = basename( $path );
			print "File exists! [$file|$path]\n\t$$hash{$file}{class}\n"
				if 0 && exists $$hash{$file};
			@{$hash->{$path}}{qw( file library )} = ($file, $dir);
			}

		}

	clear_status();

	return $hash;
	}

sub populate_hlist
	{
	my( $inc, $hlist ) = @_;

	print_status( "Creating module list..." );

	foreach my $path ( sort { lc $a cmp lc $b } keys %$inc )
		{
		my @parts = split m|/|, $path;

		# Turn path into a class
		my( $package ) = map { my $x = $_; $x =~ s|/|::|g; $x =~ s/\.p(?:m|od)\z//; $x }
			$path;

		for( my $i = 0; $i < @parts; $i++ )
			{
			# this is the relative path
			my $part = join "/", @parts[0..$i];
			my $file = join "/", $inc->{$path}{'library'}, $path;
			my $data = join "\000", $package, $file;

			$hlist->add( $part, -text => $parts[$i], -data => $data )
				unless $hlist->info('exists', $part );
			$hlist->hide( 'entry', $part ) unless $i == 0;
			}

		}

	clear_status();
	}

sub make_labels
	{
	foreach my $ref (
			[ qw(Package package)],
			[ qw(Author author) ],
			[ qw(UserID userid) ],
			[ qw(Installed inst_version) ],
			[ qw(CPAN cpan_version) ],
			[ qw(Description description) ],
			[ 'Local File', qw(inst_file) ],
			[ 'CPAN File', qw(cpan_file) ],
			)
		{
		my( $label, $name ) = @$ref;

		make_label_entry_pair( $Widgets{'meta_tab'}, $label, $name );

		$Labels{$name}++;
		}
	}

sub make_label_entry_pair
	{
	my( $widget, $label, $name ) = @_;

	my $new_frame = $widget->Frame->pack(
		-anchor => 'n',
		-fill   => 'both'
		);

	my $description = $new_frame->Label(
		-text   => $label,
		-width  => 10,
		-anchor => 'e',
		)->pack(
			-side => 'left'
			);

	$Widgets{$name} = $new_frame->Entry(
		-selectbackground => 'green',
		-exportselection  => 1,
		-width            => 50,
			)->pack(
				-side => 'left'
				);

	$Widgets{$name}->configure( -state => 'disabled' );
	}

sub make_version_labels
	{
	foreach my $version ( sort keys %Module::CoreList::version )
		{
		make_label_entry_pair( $Widgets{'core_tab'}, $version, $version );
		}
	}

sub clear_module
	{
	delete_text( $Widgets{'pod'}    );
	delete_text( $Widgets{'code'}   );
	delete_text( $Widgets{'symbol'} );
	delete_text( $Widgets{'prereq'} );

	update_info_pane(); #XXX: this is broken
	display_corelist();
	display_isa();

	update_add_favorite();

	clear_status();
	}

sub display_module
	{
	my( $package, $file ) = @_;

	return unless defined $package;

	clear_module();

	my $hash = module_info( $package );

	$file ||= $hash->{'inst_file'};

	print_status( "Fetching info for $package $hash->{inst_version}..." );

 	display_pod( $file );
	display_code( $file );
	display_symbols( $package );
	display_corelist( $package );
	display_prereq( $package, $file );
	display_isa( $package );

	update_info_pane( $hash );

	add_to_recent( $package );
	update_add_favorite( $package );

	print_status( "Showing $package $hash->{inst_version}..." );
	}

sub display_isa
	{
	my( $package, $file ) = @_;

	my $output = do {
		if( defined $package )
			{
			eval "use $package";
			join "\n", Class::ISA::super_path( $package );
			}
		else
			{
			''
			}
		};

	replace_text( $Widgets{'isa'}, \$output );
	}

sub display_prereq
	{
	my( $package, $file ) = @_;

	my $hash = Module::ScanDeps::scan_deps( files => [ $file ], recurse => 0 );

	my $output = '';

	foreach my $key ( sort { lc $a cmp lc $b } keys %$hash )
		{
		next if $key =~ m|^auto/|;
		$output .= "$key\n";
		}

	replace_text( $Widgets{'prereq'}, \$output );
	}

sub display_corelist
	{
	my $package = defined $_[0] ? $_[0] : '';

	foreach my $core (  keys %Module::CoreList::version )
		{
		my $version = exists $Module::CoreList::version{$core}{$package} ?
			$Module::CoreList::version{$core}{$package} :
			'';

		$Widgets{$core}->configure( -state => 'normal'   );
		$Widgets{$core}->configure( -text => \$version    );
		$Widgets{$core}->configure( -state => 'disabled' );
		}
	}

sub display_symbols
	{
	my $package = shift;

	my $symbols = Devel::Symdump->new( $package );

	my $output = $symbols->as_string;

	replace_text( $Widgets{'symbol'}, \$output );
	}

sub display_pod
	{
	my $file = shift;

	my $pod = $file;
	$pod =~ s/\.pm\z/.pod/;

	my $output = do {
		my $data = '';

		if( -e $file and $data = get_pod( $file ) )
			{
			$data;
			}
		elsif( -e $pod and $data = get_pod( $pod ) )
			{
			$data || "No pod found for $file";
			}
		else
			{
			"File not found\n$file\n$pod";
			}
		};

	replace_text( $Widgets{'pod'}, \$output );
	}

sub display_code
	{
	my $file = shift;

	open my($fh), $file;

	my $output = '';

	while( <$fh> )
		{
		#$output .= sprintf "%05d %s", $., $_;
		$output .= $_;
		}

	replace_text( $Widgets{'code'}, \$output );
	}

sub text_widget
	{
	my $widget = shift;
	my $type   = shift;

	my $codetext = $widget->Scrolled( 'CodeText',
		-disablemenu      => 0,
		-rulesdir         => "$ENV{HOME}/.perlbrowser/rules",
		-scrollbars       => 're',
		-height           => 25,
		-state            => 'disabled',
		-width            => 80,
		-exportselection  => 1,
		-wrap             => 'none',
		-selectbackground => 'green',
		-background       => 'white',
		-syntax           => $type,
		)->pack(
			-anchor => 'w',
			-side   => 'left',
			-expand => 1,
			-fill   => 'both' );

	modify_codetext_menu( $codetext->menu );

	return $codetext;
	}

sub modify_codetext_menu
	{
	my $menu = shift;

	my $last = $menu->index( 'last' );

	foreach my $index ( () ) #reverse 0 .. $last )
		{
		my $label = $menu->entrycget( $index, 'label' );
		$menu->delete( $index ) if $label =~ m/(?:File|Edit)/i;
		}
	}

sub replace_text
	{
	my $widget   = shift;
	my $text_ref = shift;

	my $default = "";
	$text_ref ||= \$default;

	#$text_ref = \$text_ref unless ref $text_ref;

	$widget->configure( -state => 'normal' );
	$widget->delete( '1.0', 'end' );
	$widget->insert("end", $$text_ref );
	$widget->configure( -state => 'disabled' );
	}

sub delete_text
	{
	my $widget   = shift;

	$widget->configure( -state => 'normal' );
	$widget->delete( '1.0', 'end' );
	$widget->configure( -state => 'disabled' );
	}

sub mw_configure
	{
	my $mw = shift;

	$mw->resizable(0,1);

	$mw->configure( -menu => $Widgets{'menubar'} = $mw->Menu );
	$mw->title( "perlbrowser" );

	$Widgets{'file_menu'} = $Widgets{'menubar'}->cascade(
		-label     => "File",
		-menuitems => [[qw( command ~Quit -accelerator ^Q -command ), [ \&my_exit ] ]],
		-tearoff   => 0,
		);

	$Widgets{'edit_menu'} = $Widgets{'menubar'}->cascade(
		-label     => "Edit",
		-menuitems => [
			[qw( command Cut -accelerator ^X -state disabled ) ],
			[qw( command Copy -accelerator ^C -state disabled )],
			[qw( command Paste -accelerator ^V -state disabled ) ],
			[qw( command ), 'Select All', qw( -accelerator ^A -state disabled ) ],
			],
		-tearoff   => 0,
		);

	$Widgets{'inc_menu'} = $Widgets{'menubar'}->cascade(
		-label     => "\@INC",
		-menuitems => [
			map( { [ 'checkbutton', $_, -variable => \$My_INC{$_} ] } keys %My_INC ),
			'separator',
			[ 'command', 'Add directory...', -state => 'disabled' ],
			[qw( command Rescan -command ), [ \&make_hlist  ] ],
			[qw( command Clear  -command ), [ \&clear_hlist ] ],
			],
		-tearoff   => 0,
		);

	$Widgets{'recent_menu'} = $Widgets{'menubar'}->cascade(
		-label     => "Recent",
		-menuitems => [
			'separator',
			[ 'command',  'Clear Menu',  -state => 'normal',
				-command => \&clear_recent ],
			],
		-tearoff   => 0,
		);

	$Widgets{'fav_menu'} = $Widgets{'menubar'}->cascade(
		-label     => "Favorites",
		-menuitems => [
			'separator',
			[ 'command', 'Add favorite...', -accelerator => '^F',
				-state => 'disabled' ],
			],
		-tearoff   => 0,
		);

	key_bindings( $mw );
	}

sub get_list_children
	{
	my @kids = $Widgets{'hlist'}->info('children', $_[0]);
	}

sub do_list_action
	{
	my( $action, $kids ) = @_;

	foreach my $kid ( @$kids )
		{
		$Widgets{'hlist'}->$action('entry', $kid );
		}
	}

sub expand_list
	{
	my $kids = shift;

	do_list_action( 'show', $kids );
	}

sub shrink_list
	{
	my $kids = shift;

	do_list_action( 'hide', $kids );
	}

sub add_label_frame
	{
	my( $frame, $label, $name, $initial ) = @_;

	$initial = defined $initial ? $initial : 'Foo';

	my $new_frame   = $frame->Frame->pack( -anchor => 'n', -fill => 'both' );

	my $description = $new_frame->Label( -text => $label, -width => 10, -anchor => 'e',
		)->pack( -side => 'left' );

	print "Name is $name\n" if DEBUG;
	$Widgets{$name}    = $new_frame->Entry(
		-text => $initial, -exportselection => 1, -state => 'disabled', -width => 50,
			)->pack( -side => 'left' );
	}

sub add_help
	{
	my $file = $0;
	print_status( "script is $file" );

	my $text = get_pod( $file );

	replace_text( $Widgets{'help'}, \$text, 'Tk::CodeText::Perl' );

	clear_status;
	}

sub key_bindings
	{
	my $mw = shift;

	$mw->bind( '<Control-q>', \&my_exit );
	$mw->bind( '<Control-r>', \&make_hlist );

	$mw->bind( '<Control-c>', sub { $Widgets{'notebook'}->raise('code')    } );
	$mw->bind( '<Control-d>', sub { $Widgets{'notebook'}->raise('pod')     } );
	$mw->bind( '<Control-m>', sub { $Widgets{'notebook'}->raise('meta')    } );
	$mw->bind( '<Control-h>', sub { $Widgets{'notebook'}->raise('help')    } );
	$mw->bind( '<Control-i>', sub { $Widgets{'notebook'}->raise('isa')     } );
	$mw->bind( '<Control-p>', sub { $Widgets{'notebook'}->raise('prereq')  } );
	$mw->bind( '<Control-s>', sub { $Widgets{'notebook'}->raise('symbol') } );
	$mw->bind( '<Control-f>', sub { add_favorite()      } );
	}

sub dump_keybindings
	{
	return unless DEBUG;

	foreach my $index ( qw(q m) )
		{
		print "$index: ", Data::Dumper::Dumper( $mw->bind( "<Control-$index>" ) );
		}

	foreach my $index ( 0 .. 1 )
		{
		print "$index: ", Data::Dumper::Dumper( $mw->bind( "<Shift-$index>"   ) );
		print "$index: ", Data::Dumper::Dumper( $mw->bind( "<Control-$index>" ) );
		}
	}

sub update_info_pane
	{
	my $hash = shift;

	unless( UNIVERSAL::isa( $hash, 'HASH' ) )
		{
		foreach my $name ( keys %Labels )
			{
			next unless exists $Widgets{$name};
			$Widgets{$name}->configure( -state => 'normal' );
			$Widgets{$name}->delete( 0, 'end' );
			$Widgets{$name}->configure( -state => 'disabled' );
			}

		return;
		}

	foreach my $value ( keys %$hash )
		{
		next unless exists $Widgets{$value};
		$Widgets{$value}->configure( -state => 'normal' );
		$Widgets{$value}->delete( 0, 'end' );
		$Widgets{$value}->insert( 0, $hash->{$value} );
		$Widgets{$value}->configure( -state => 'disabled' );
		}
	}

sub my_exit
	{
	print_status( "Exiting..." );

	save_favorites();
	save_recent();

	exit
	};

sub save_favorites
	{
	print_status( "Saving favorites..." );

	open my($fh), "> $ENV{HOME}/.perlbrowser/favorites.txt";

	foreach my $key ( keys %Favorites )
		{
		print $fh $key, "\n";
		}

	close $fh;

	clear_status();
	}

sub load_favorites
	{
	print_status( "Loading favorites..." );

	open my($fh), "$ENV{HOME}/.perlbrowser/favorites.txt";

	while( <$fh> )
		{
		chomp;
		add_favorite( $_ );
		}

	close $fh;

	clear_status();
	}

sub save_recent
	{
	print_status( "Saving recent..." );

	my $menu = $Widgets{'recent_menu'}->menu;

	my $last = $menu->index('last');

	open my($fh), "> $ENV{HOME}/.perlbrowser/recent.txt";

	foreach my $index ( reverse 0 .. $last - 2 )
		{
		my $module = $menu->entrycget( $index, 'label' );
		print $fh $module, "\n";
		}

	close $fh;

	clear_status();
	}

sub load_recent
	{
	print_status( "Loading recent..." );

	open my($fh), "$ENV{HOME}/.perlbrowser/recent.txt"
		or return;

	while( <$fh> )
		{
		chomp;
		add_to_recent( $_ );
		}

	close $fh;

	clear_status();
	}
