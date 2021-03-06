package CoGe::Accessory::Utils;

=head1 NAME

CoGe::Accessory::Utils

=head1 SYNOPSIS

Miscellaneous utility functions.

=head1 DESCRIPTION

=head1 AUTHOR

Matt Bomhoff

=head1 COPYRIGHT

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

=cut

use strict;
use warnings;

use POSIX qw( ceil );
use Data::GUID;
use Data::Dumper;
use File::Basename qw(fileparse);

BEGIN {
    use vars qw ($VERSION $FASTA_LINE_LEN @ISA @EXPORT);
    require Exporter;

    $VERSION = 0.1;
    $FASTA_LINE_LEN = 80;
    @ISA     = qw (Exporter);
    @EXPORT = qw( 
        units commify print_fasta get_unique_id get_link_coords 
        format_time_diff sanitize_name execute 
        trim js_escape html_escape to_filename to_pathname
        is_fastq_file
    );
}

sub units {
    my $val = shift;

    if ( $val < 1024 ) {
        return $val;
    }
    elsif ( $val < 1024 * 1024 ) {
        return ceil( $val / 1024 ) . 'K';
    }
    elsif ( $val < 1024 * 1024 * 1024 ) {
        return ceil( $val / ( 1024 * 1024 ) ) . 'M';
    }
    else {
        return ceil( $val / ( 1024 * 1024 * 1024 ) ) . 'G';
    }
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub trim {
    my $s = shift;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/^\"//;
    $s =~ s/\"$//;
    return $s;
}

sub js_escape {
    my $s = shift;
    $s =~ s/[\x00-\x1f]/ /g; # remove non-printable ascii chars
    $s =~ s/\'/\\'/g;
    $s =~ s/\"/\\"/g;
    return $s;
}

sub html_escape {
    my $s = shift;
    $s =~ s/[\x00-\x1f]/ /g; # remove non-printable ascii chars
    $s =~ s/\'/\&\#8216\;/g; # convert apostrophe char
    return $s;
}

sub print_fasta {
	my $fh = shift;
	my $name = shift;	# fasta section name
	my $pIn = shift; 	# reference to section data

	my $len = length $$pIn;
	my $ofs = 0;

	print {$fh} ">$name\n";
    while ($ofs < $len) {
    	print {$fh} substr($$pIn, $ofs, $FASTA_LINE_LEN) . "\n";
    	$ofs += $FASTA_LINE_LEN;
    }
}

sub get_unique_id {
	my $id = Data::GUID->new->as_hex;
	$id =~ s/^0x//;
	return $id;
}

sub get_link_coords { # mdb added 11/20/13 issue 254
	my ($start, $stop) = @_;
	return ($start, $stop) unless (defined $start and defined $stop);

	my $offset = 500;#int( abs($stop-$start+1) / 4 );
	($start, $stop) = ($stop, $start) if ($start > $stop);
	$start -= $offset;
	$stop  += $offset;
	return ($start, $stop);
}

# Convert a string to filename-friendly version
sub sanitize_name { 
    my $name = shift;
    
    return unless (defined $name);

    $name =~ s/\///g;   # remove /
    $name =~ s/\s+/_/g; # replace whitespace with _
    $name =~ s/\(//g;   # remove (
    $name =~ s/\)//g;   # remove )
    $name =~ s/://g;    # remove :
    $name =~ s/;//g;    # remove ;
    $name =~ s/#/_/g;   # replace # with _
    $name =~ s/'//g;    # remove '
    $name =~ s/"//g;    # remove "

    return $name;
}

sub format_time_diff {
    my $diff = shift;

    my $d = int($diff / (60*60*24));
    $diff -= $d * (60*60*24);
    my $h = int($diff / (60*60));
    $diff -= $h * (60*60);
    my $m = int($diff / 60);
    $diff -= $m * 60;
    my $s = $diff % 60;

    my $elapsed = '';
    $elapsed .= "${d}d " if $d > 0;
    $elapsed .= "${h}h " if $h > 0;
    $elapsed .= "${m}m " if $m > 0 && $d <= 0;
    $elapsed .= "${s}s" if $s > 0 && $d <= 0;

    return $elapsed;
}

sub to_filename {
    my ($name, undef, undef) = fileparse(shift, qr/\.[^.]*/);
    return $name;
}

sub to_pathname {
    my (undef, $path, undef) = fileparse(shift, qr/\.[^.]*/);
    return $path;
}

sub execute {
    my $cmd = shift;
    my $error_msg = shift; # optional

    my @cmdOut = qx{$cmd};
    my $cmdStatus = $?;

    if ($cmdStatus != 0) {
        if ($error_msg) {
            print STDERR $error_msg;
        }
        else {
            say STDERR "error: command failed with rc=$cmdStatus: $cmd";
        }
    }

    return $cmdStatus;
}

sub is_fastq_file {
    my $filename = shift;
    return ($filename =~ /fastq$/ || $filename =~ /fastq\.gz$/ || $filename =~ /fq$/ || $filename =~ /fq\.gz$/);
}

1;
