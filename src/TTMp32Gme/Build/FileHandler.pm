package TTMp32Gme::Build::FileHandler;

use strict;
use warnings;

use PAR;
use Path::Class;
use File::Copy::Recursive qw(dirmove);
use Log::Message::Simple qw(msg debug error);
use Data::Dumper;
use Encode qw(_utf8_off);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT =
	qw(loadTemplates loadAssets openBrowser get_default_library_path checkConfigFile loadStatic makeTempAlbumDir makeNewAlbumDir moveToAlbum removeTempDir clearAlbum removeAlbum cleanup_filename remove_library_dir get_executable_path get_oid_cache get_tiptoi_dir get_gmes_already_on_tiptoi delete_gme_tiptoi move_library);
my @build_imports = qw(loadFile get_local_storage get_par_tmp loadTemplates loadAssets openBrowser);

if ( PAR::read_file('build.txt') ) {
	if ( $^O eq 'darwin' ) {
		require TTMp32Gme::Build::Mac;
		import TTMp32Gme::Build::Mac @build_imports;
	} elsif ( $^O =~ /MSWin/ ) {
		require TTMp32Gme::Build::Win;
		import TTMp32Gme::Build::Win @build_imports;
	}
} else {
	require TTMp32Gme::Build::Perl;
	import TTMp32Gme::Build::Perl @build_imports;
}

## private functions:

sub get_unique_path {
	my ($path) = @_;
	my $count = 0;
	while ( -e $path ) {
		$path =~ s/_\d*$//;
		$path .= '_' . $count;
		$count++;
	}
	return $path;
}

##public functions:

sub get_default_library_path {
	my $library = dir( get_local_storage(), 'library' );
	$library->mkpath();
	return $library->stringify();
}

sub checkConfigFile {
	my $configdir  = get_local_storage();
	my $configfile = file( $configdir, 'config.sqlite' );
	if ( !-f $configfile ) {
		my $cfgToCopy = file( get_par_tmp(), 'config.sqlite' );
		$cfgToCopy->copy_to($configfile)
			or die "Could not create local copy of config file '$cfgToCopy': $!";
	}
	if ( $^O =~ /MSWin/ ) {
		return Win32::GetShortPathName($configfile);
	} else {
		return $configfile;
	}
}

sub loadStatic {
	my $static      = {};
	my @staticFiles = ( 'upload.html', 'library.html', 'config.html', 'help.html', );
	foreach my $file (@staticFiles) {
		$static->{$file} = loadFile($file);
	}

	return $static;
}

sub makeTempAlbumDir {
	my ( $temp_name, $library_path ) = @_;
	$library_path = $library_path ? $library_path : get_default_library_path();
	my $albumPath = dir( $library_path, 'temp', $temp_name );
	$albumPath->mkpath();
	return $albumPath;
}

sub makeNewAlbumDir {
	my ( $albumTitle, $library_path ) = @_;
	$library_path = $library_path ? $library_path : get_default_library_path();

	#make sure no album hogs the temp directory
	if ( $albumTitle eq 'temp' ) {
		$albumTitle .= '_0';
	}
	my $album_path =
		get_unique_path( ( dir( $library_path, $albumTitle ) )->stringify );
	$album_path = dir($album_path);
	$album_path->mkpath();
	return $album_path->stringify;
}

sub moveToAlbum {
	my ( $albumPath, $filePath ) = @_;
	my $file        = file($filePath);
	my $target      = get_unique_path( file( $albumPath, cleanup_filename( $file->basename() ) )->stringify );
	my $target_file = file($target);
	my $album_file  = $file->move_to($target_file);
	return $album_file->basename();
}

sub removeTempDir {
	my ($library_path) = @_;
	$library_path = $library_path ? $library_path : get_default_library_path();
	my $tempPath = dir( $library_path, 'temp' );
	if ( $tempPath =~ /temp/ && -d $tempPath ) {
		print "deleting $tempPath\n";
		$tempPath->rmtree();
	}
	return 1;
}

sub clearAlbum {
	my ( $path, $file_list, $library_path ) = @_;
	$library_path = $library_path ? $library_path : get_default_library_path();
	$library_path =~ s/\\/\\\\/g;    #fix windows paths
	if ( $path =~ /^$library_path/ ) {
		foreach my $file ( @{$file_list} ) {
			if ($file) {
				my $full_file = file( $path, $file );
				if ( -f $full_file ) {
					$full_file->remove();
				}
			}
		}
		return 1;
	} else {
		return 0;
	}
}

sub cleanup_filename {
	my $filename = $_[0];
	$filename =~ s/\s/_/g;
	$filename =~ s/[^A-Za-z0-9_\-\.]//g;
	$filename =~ s/\.\./\./g;
	$filename =~ s/\.$//g;
	_utf8_off($filename)
		; #prevent perl from messing up filenames with non-ascii characters because of perl open() bug: https://github.com/perl/perl5/issues/15883
	return $filename;
}

sub remove_library_dir {
	my ( $media_path, $library_path ) = @_;
	$library_path = $library_path ? $library_path : get_default_library_path();
	my $media_dir = dir($media_path);
	$library_path =~ s/\\/\\\\/g;    #fix windows paths
	if ( $media_dir =~ /^$library_path/ ) {
		$media_dir->rmtree();
		return 1;
	} else {
		return 0;
	}
}

sub get_executable_path {
	my $exe_name = $_[0];
	if ( $^O =~ /MSWin/ ) {
		$exe_name .= '.exe';
	}
	my $exe_path;
	if ( PAR::read_file('build.txt') ) {
		$exe_path = ( file( get_par_tmp(), 'lib', $exe_name ) )->stringify();
	} else {
		if ( $^O =~ /MSWin/ ) {
			$exe_path =
				( file( get_par_tmp(), '..', 'lib', 'win', $exe_name ) )->stringify();
		} elsif ( $^O eq 'darwin' ) {
			$exe_path =
				( file( get_par_tmp(), '..', 'lib', 'mac', $exe_name ) )->stringify();
		} else {
			$ENV{'PATH'} = $ENV{'PATH'} . ':/usr/local/bin';
			my $foo = `which $exe_name`;
			chomp($foo);
			$exe_path = $foo;
		}
	}
	if ( -x $exe_path ) {
		return $exe_path;
	} else {
		return "";
	}
}

sub get_oid_cache {
	my $oid_cache = dir( get_local_storage(), 'oid_cache' );
	if ( !-d $oid_cache ) {
		$oid_cache->mkpath();
		my $cache = dir( get_par_tmp(), 'oid_cache' );
		$cache->recurse(
			callback => sub {
				my ($file) = @_;
				if ( -f $file && $file =~ /\.png$/ ) {
					$file->copy_to( file( $oid_cache, $file->basename() ) );
				}
			}
		);
	}
	return $oid_cache->stringify();
}

sub get_tiptoi_dir {
	if ( $^O eq 'darwin' ) {
		my @tiptoi_paths =
			( dir( '', 'Volumes', 'tiptoi' ), dir( '', 'Volumes', 'TIPTOI' ) );
		foreach my $tiptoi_path (@tiptoi_paths) {
			if ( -w $tiptoi_path ) {
				return $tiptoi_path;
			}
		}
	} elsif ( $^O =~ /MSWin/ ) {
		require Win32API::File;
		my @drives = Win32API::File::getLogicalDrives();
		foreach my $d (@drives) {
			my @info = (undef) x 7;
			Win32API::File::GetVolumeInformation( $d, @info );
			if ( lc $info[0] eq 'tiptoi' ) {
				return dir($d);
			}
		}
	} else {
		my $user         = $ENV{'USER'} || "root";
		my @mount_points = (
			'/mnt/tiptoi', "/media/$user/tiptoi", '/media/removable/tiptoi', "/media/$user/TIPTOI",
			'/media/removable/TIPTOI'
		);
		foreach my $mount_point (@mount_points) {
			if ( -f "$mount_point/tiptoi.ico" ) {
				return dir($mount_point);
			}
		}
	}
	return 0;
}

sub get_gmes_already_on_tiptoi {
	my $tiptoi_path = get_tiptoi_dir();
	if ($tiptoi_path) {
		my @gme_list  = grep( !$_->is_dir && $_->basename =~ /^(?!\._).*\.gme\z/, $tiptoi_path->children() );
		my %gme_names = map { $_->basename => 1 } @gme_list;
		return %gme_names;
	} else {
		return ();
	}
}

sub delete_gme_tiptoi {
	my ( $oid, $dbh, $debug ) = @_;
	my $album_data = $dbh->selectrow_hashref( q(SELECT gme_file FROM gme_library WHERE oid=?), {}, $oid );
	if ( $album_data->{'gme_file'} ) {
		my $gme_file = file( get_tiptoi_dir(), $album_data->{'gme_file'} );
		if ($debug) { debug( 'Attempting to delete: ' . $gme_file->stringify(), $debug ); }
		if ( $gme_file->remove() ) {
			msg( 'Deleted: ' . $gme_file->stringify(), \1 );
			return $oid;
		} elsif ($debug) {
			debug( 'Failed to delete: ' . $gme_file->stringify(), $debug );
		}
	}
	return 0;
}

sub move_library {
	my ( $from, $to, $dbh, $httpd, $debug ) = @_;
	debug( 'raw: ' . $to, $debug );
	my $library = dir($to);
	unless ( -w $library || $library->mkpath() ) {
		return 'error: could not write to target directory';
	}
	debug( 'mkdir: ' . $library, $debug );
	$library->resolve;
	debug( 'resolved: ' . $library, $debug );
	if ( $library->children() ) {
		return 'error: target directory not empty';
	}
	my $albums = $dbh->selectall_hashref( q( SELECT path, oid FROM gme_library ), 'oid' );
	my $qh     = $dbh->prepare('UPDATE gme_library SET path=? WHERE oid=?');
	local ( $dbh->{AutoCommit} ) = 0;
	my $escFrom = $from;
	$escFrom =~ s/\\/\\\\/g;
	foreach my $oid ( sort keys %{$albums} ) {
		eval { $qh->execute( $albums->{$oid}->{'path'} =~ s/$escFrom/$library/r, $oid ); }
	}
	if ($@) {
		$dbh->rollback();
		return 'error: could not update album path in database';
	} else {
		if ( dirmove( $from, $library ) ) {
			$dbh->commit();
			return 'Success.';
		} else {
			my $errMsg = $!;
			$dbh->rollback();
			return 'error: could not move files: ' . $errMsg;
		}
	}
}

1;
