#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use CoGeX;
use Getopt::Long;
use File::Path;
use File::Touch;
use File::Basename qw(basename);
use File::Spec::Functions qw(catdir catfile);
use URI::Escape::JavaScript qw(unescape);
use JSON::XS;
use CoGe::Accessory::Web qw(get_defaults);
use CoGe::Accessory::Utils qw( commify to_pathname );
use CoGe::Core::Genome qw(fix_chromosome_id);
use CoGe::Accessory::TDS;
use CoGe::Core::Storage qw(add_workflow_result);
use CoGe::Core::Metadata qw(create_annotations);

use vars qw($staging_dir $result_file $install_dir $data_file $file_type 
  $name $description $version $restricted $ignore_missing_chr $creator_id $normalize
  $gid $source_name $user_name $config $allow_negative $disable_range_check
  $user_id $annotations $types $wid $host $port $db $user $pass $P);

#FIXME: use these from Storage.pm instead of redeclaring them
my $DATA_TYPE_QUANT  = 1; # Quantitative data
my $DATA_TYPE_POLY	 = 2; # Polymorphism data
my $DATA_TYPE_ALIGN  = 3; # Alignments
my $DATA_TYPE_MARKER = 4; # Markers

#my $MIN_QUANT_COLUMNS = 5;
#my $MAX_QUANT_COLUMNS = 6;
my $MIN_VCF_COLUMNS = 8;
#my $MAX_VCF_COLUMNS = 10;
my $MIN_GFF_COLUMNS = 9;

GetOptions(
    "staging_dir=s" => \$staging_dir,    # temporary staging path
    "install_dir=s" => \$install_dir,    # final installation path
#    "result_file=s" => \$result_file,    # results file
    "data_file=s"   => \$data_file,      # input data file (JS escape)
    "file_type=s"   => \$file_type,		 # input file type
    "name=s"        => \$name,           # experiment name (JS escaped)
    "desc=s"        => \$description,    # experiment description (JS escaped)
    "version=s"     => \$version,        # experiment version (JS escaped)
    "restricted=s"  => \$restricted,     # experiment restricted flag (0|1 or false|true)
    "source_name=s" => \$source_name,    # experiment source name (JS escaped)
    "gid=s"         => \$gid,            # genome id
    "wid=s"         => \$wid,            # workflow id
    "user_id=i"     => \$user_id,        # user ID to assign experiment
    "user_name=s"   => \$user_name,      # user name to assign experiment (alternative to user_id)
    "creator_id=i"  => \$creator_id,     # user ID to set as experiment creator
    "annotations=s" => \$annotations,    # optional: semicolon-separated list of locked annotations (link:group:type:text;...)
    "types=s"       => \$types,          # optional: semicolon-separated list of experiment type names
    "normalize=s"   => \$normalize,      # optional: percentage, log10 or loge    
    "config=s"      => \$config,         # configuration file

    # Optional flags for debug and bulk loader
    "ignore-missing-chr=i" => \$ignore_missing_chr,
    "allow_negative=i"     => \$allow_negative,
    "disable_range_check"  => \$disable_range_check, # allow any value in val1 column
);

$| = 1;
print STDOUT "Starting $0 (pid $$)\n", qx/ps -o args $$/;

# Setup supported file types
my @QUANT_TYPES = qw(csv tsv bed wig);
my @MARKER_TYPES = qw(gff gtf gff3);
my @OTHER_TYPES = qw(bam vcf);
my @SUPPORTED_TYPES = (@QUANT_TYPES, @MARKER_TYPES, @OTHER_TYPES);

# Setup staging path
unless ($staging_dir) {
    print STDOUT "log: error: staging_dir argument is missing\n";
    exit(-1);
}
mkpath($staging_dir, 0, 0777) unless -r $staging_dir;

# Prevent loading again (issue #417)
my $logdonefile = "$staging_dir/log.done";
if (-e $logdonefile) {
    print STDOUT "log: error: done file already exists: $logdonefile\n";
    exit(-1);
}

# Process and verify parameters
$data_file   = unescape($data_file);
$name        = unescape($name);
$description = unescape($description);
$version     = unescape($version);
$source_name = unescape($source_name);

unless ($wid) {
    print STDOUT "log: error: required workflow ID not specified\n";
    exit(-1);
}

unless ($data_file && -r $data_file) {
    print STDOUT "log: error: cannot access input data file\n";
    exit(-1);
}

if (not defined $user_id and not defined $user_name) {
    print STDOUT "log: error: user not specified, use user_id or user_name\n";
    exit(-1);
}

if ((defined $user_name and $user_name eq 'public') || (defined $user_id and $user_id eq '0')) {
    print STDOUT "log: error: not logged in\n";
    exit(-1);
}

# Set default parameters
$restricted  = '1' unless (defined $restricted && (lc($restricted) eq 'false' || $restricted eq '0'));
$ignore_missing_chr = '1' unless (defined $ignore_missing_chr); # mdb added 10/6/14 easier just to make this the default

# Load config file
unless ($config) {
    print STDOUT "log: error: can't find config file\n";
    print STDERR "can't find config file\n";
    exit(-1);
}
$P    = CoGe::Accessory::Web::get_defaults($config);
$db   = $P->{DBNAME};
$host = $P->{DBHOST};
$port = $P->{DBPORT};
$user = $P->{DBUSER};
$pass = $P->{DBPASS};

my $FASTBIT_LOAD  = $P->{FASTBIT_LOAD};
my $FASTBIT_QUERY = $P->{FASTBIT_QUERY};
my $SAMTOOLS      = $P->{SAMTOOLS};
my $GUNZIP        = $P->{GUNZIP};
if (   not $FASTBIT_LOAD
    or not $FASTBIT_QUERY
    or not $SAMTOOLS
    or not $GUNZIP
    or not -e $FASTBIT_LOAD
    or not -e $FASTBIT_QUERY
    or not -e $SAMTOOLS
    or not -e $GUNZIP )
{
    print STDOUT "log: error: can't find required command(s)\n";
    exit(-1);
}

# Copy input data file to staging area
# If running via JEX the file will already be there
my ($filename) = basename($data_file);
my $staged_data_file = $staging_dir . '/' . $filename;
unless (-r $staged_data_file) {
    my $cmd;
    $cmd = "cp -f '$data_file' $staging_dir";
    `$cmd`;
}

# Decompress file if necessary
if ( $staged_data_file =~ /\.gz$/ ) {
    my $cmd = $GUNZIP . ' ' . $staged_data_file;
    print STDOUT "log: Decompressing '$filename'\n";
    `$cmd`;
    $staged_data_file =~ s/\.gz$//;
}

# Determine file type
my ($file_type, $data_type) = detect_data_type($file_type, $staged_data_file);
if ( !$file_type or !$data_type ) {
    my $types = join ",", sort {$a cmp $b} @SUPPORTED_TYPES;
    print STDOUT "log: error: unknown or unsupported file type '$file_type'\n";
    print STDOUT "log: file must end with one of the following types: $types\n";
    exit(-1);
}

# Connect to database
my $connstr = "dbi:mysql:dbname=$db;host=$host;port=$port;";
my $coge = CoGeX->connect( $connstr, $user, $pass );
unless ($coge) {
    print STDOUT "log: couldn't connect to database\n";
    exit(-1);
}

# Retrieve user
my $user;
if ($user_id) {
    $user = $coge->resultset('User')->find($user_id);
}
elsif ($user_name) {
    $user = $coge->resultset('User')->find( { user_name => $user_name } );
}
else {
    print STDOUT "log: error user not specified, see user_id or user_name\n";
    exit(-1);
}

unless ($user) {
    print STDOUT "log: error finding user ", ($user_name ? $user_name : $user_id) , "\n";
    exit(-1);
}

# Retrieve creator
my $creator;
if ($creator_id) {
    $creator = $coge->resultset('User')->find($creator_id);
    unless ($creator) {
        print STDOUT "log: error finding creator $creator_id\n";
        exit(-1);
    }
}
$creator = $user unless $creator;

# Retrieve genome
my $genome = $coge->resultset('Genome')->find( { genome_id => $gid } );
unless ($genome) {
    print STDOUT "log: error finding genome id$gid\n";
    exit(-1);
}

# Hash chromosome names
my %genome_chr = map { $_ => 1 } $genome->chromosomes;

# Validate the data file
print STDOUT "log: Validating data file\n";
if (-s $staged_data_file == 0) {
    print STDOUT "log: error: input file '", basename($staged_data_file), "' is empty\n";
    exit(-1);
}
my ($count, $pChromosomes, $format);
if ( $data_type == $DATA_TYPE_QUANT ) {
    ( $staged_data_file, $format, $count, $pChromosomes ) =
      validate_quant_data_file( file => $staged_data_file, file_type => $file_type, genome_chr => \%genome_chr );
}
elsif ( $data_type == $DATA_TYPE_POLY ) {
    ( $staged_data_file, $format, $count, $pChromosomes ) =
      validate_vcf_data_file( file => $staged_data_file, genome_chr => \%genome_chr );
}
elsif ( $data_type == $DATA_TYPE_ALIGN ) {
	( $staged_data_file, $format, $count, $pChromosomes ) =
      validate_bam_data_file( file => $staged_data_file, genome_chr => \%genome_chr );
}
elsif ( $data_type == $DATA_TYPE_MARKER ) {
    ( $staged_data_file, $format, $count, $pChromosomes ) =
      validate_gff_data_file( file => $staged_data_file, genome_chr => \%genome_chr );
}
if ( !$count ) {
    print STDOUT "log: error: file contains no data\n";
    exit(-1);
}
print STDOUT "log: Successfully read " . commify($count) . " lines\n";

# Verify that chromosome names in input file match those for genome
my $print_limit = 50;
foreach ( sort keys %genome_chr ) {
    print STDOUT "genome chromosome $_\n";
    if ($print_limit-- == 0) {
        print STDOUT "... (stopping here, too many genome chromosomes to show)\n";
        last;
    }
}
$print_limit = 50;
foreach ( sort keys %$pChromosomes ) {
    print STDOUT "input chromosome $_\n";
    if ($print_limit-- == 0) {
        print STDOUT "... stopping here, too many input chromosomes to show\n";
        last;
    }
}
	
my $missing_chr_error = 0;
foreach ( sort keys %$pChromosomes ) {
	if ( not defined $genome_chr{$_} ) { # don't repeat same error message
		if ($missing_chr_error < 5) {
			print STDOUT "log: chromosome '$_' not found in genome, skipping (only showing first 5) ...\n";
		}
	        $missing_chr_error++;
	}
}

if (not $ignore_missing_chr) {
	if ($missing_chr_error) {
	    print STDOUT "log: error: input chromosome names don't match genome\n";
	    exit(-1);
	}
}

# Save data format doc
if ($format) {
    my $format_file = catfile($staging_dir, 'format.json');
    open(my $out, '>', $format_file);
    print $out encode_json($format);
    close($out);
}

# Generate fastbit database/index (doesn't apply to BAM files)
if ( $data_type == $DATA_TYPE_QUANT
     or $data_type == $DATA_TYPE_POLY
     or $data_type == $DATA_TYPE_MARKER )
{
    # Determine data scheme
    my $data_spec = join(',', map { $_->{name} . ':' . $_->{type} } @{$format->{columns}} );

	#TODO redirect fastbit output to log file instead of stderr
	print STDOUT "log: Generating database\n";
	my $cmd = "$FASTBIT_LOAD -d $staging_dir -m \"$data_spec\" -t $staged_data_file";
	print STDOUT $cmd, "\n";
	my $rc = system($cmd);
	if ( $rc != 0 ) {
	    print STDOUT "log: error executing ardea command: $rc\n";
	    exit(-1);
	}

	print STDOUT "log: Indexing database (may take a few minutes)\n";
	$cmd = "$FASTBIT_QUERY -d $staging_dir -v -b \"<binning precision=2/><encoding equality/>\"";
	print STDOUT $cmd, "\n";
	$rc = system($cmd);
	if ( $rc != 0 ) {
	    print STDOUT "log: error executing ibis command: $rc\n";
	    exit(-1);
	}
}

################################################################################
# If we've made it this far without error then we can feel confident about
# the input data.  Now we can go ahead and create the db entities and
# install the files.
################################################################################

# Create data source
my $data_source =
  $coge->resultset('DataSource')->find_or_create( {
      name => $source_name, description => "" }
  );#, description => "Loaded into CoGe via LoadExperiment" } );
unless ($data_source) {
    print STDOUT "log: error creating data source\n";
    exit(-1);
}

# Create experiment
my $experiment = $coge->resultset('Experiment')->create(
    {
        name        => $name,
        description => $description,
        version     => $version,
        #link				=> $link, #FIXME
        data_source_id => $data_source->id,
        data_type      => $data_type,
        row_count      => $count,
        genome_id      => $gid,
        creator_id     => $creator->id,
        restricted     => $restricted
    }
);
print STDOUT "experiment id: " . $experiment->id . "\n";

# Create types
if ($types) {
    foreach my $type_name ( split(/\s*;\s*/, $types) ) {
        # Try to find a matching type by name, ignoring description
        my $type = $coge->resultset('ExperimentType')->find({ name => $type_name });
        if (!$type) {
            $type = $coge->resultset('ExperimentType')->create({ name => $type_name }); # null description
        }
        unless ($type) {
            print STDOUT "log: error creating experiment type\n";
            exit(-1);
        }
        my $conn = $coge->resultset('ExperimentTypeConnector')->find_or_create({
            experiment_id => $experiment->id,
            experiment_type_id => $type->id
        });
        unless ($conn) {
            print STDOUT "log: error creating experiment type connector\n";
            exit(-1);
        }
    }
}

# Create annotations
if ($annotations) {
    CoGe::Core::Metadata::create_annotations(db => $coge, target => $experiment, annotations => $annotations, locked => 1);
}

# Determine installation path
unless ($install_dir) {
    unless ($P) {
        print STDOUT "log: error: can't determine install directory, set 'install_dir' or 'config' params\n";
        exit(-1);
    }
    $install_dir = $P->{EXPDIR};
}
my $storage_path = catdir($install_dir, CoGe::Core::Storage::get_tiered_path( $experiment->id ));
print STDOUT 'Storage path: ', $storage_path, "\n";

# This is a check for dev server which may be out-of-sync with prod
if ( -e $storage_path ) {
    print STDOUT "log: error: install path already exists\n";
    exit(-1);
}

#TODO create experiment type & connector

# Make user owner of new experiment
my $user = $coge->resultset('User')->find( { user_name => $user_name } );
unless ($user) {
    print STDOUT "log: error finding user '$user_name'\n";
    exit(-1);
}
my $node_types = CoGeX::node_types();
my $conn       = $coge->resultset('UserConnector')->create(
    {
        parent_id   => $user->id,
        parent_type => $node_types->{user},
        child_id    => $experiment->id,
        child_type  => $node_types->{experiment},
        role_id     => 2                            # FIXME hardcoded
    }
);
unless ($conn) {
    print STDOUT "log: error creating user connector\n";
    exit(-1);
}

# Copy files from staging directory to installation directory
mkpath($storage_path);
unless (-r $storage_path) {
	print STDOUT "log: error: could not create installation path\n";
	exit(-1);
}
my $cmd = "cp -r $staging_dir/* $storage_path"; #FIXME use perl copy and detect failure
print STDOUT "$cmd\n";
`$cmd`;

# Make sure file permissions are set properly (added for qTeller pipeline)
$cmd = "chmod -R a+r $storage_path";
print STDOUT "$cmd\n";
`$cmd`;

# Save result
add_workflow_result($user_name, $wid, 
    {
        type => 'experiment',
        id => int($experiment->id),
        name        => $name,
        description => $description,
        version     => $version,
        #link       => $link, #FIXME
        data_source_id => $data_source->id,
        data_type   => $data_type, #FIXME convert from number to string identifier
        row_count   => $count,
        genome_id   => $gid,
        restricted  => $restricted
    }
);

# Add experiment ID to log - mdb added 8/19/14, needed after log output was moved to STDOUT for jex
my $logtxtfile = "$staging_dir/log.txt";
open(my $logh, '>', $logtxtfile);
print $logh "experiment id: " . $experiment->id . "\n";
close($logh);

# Save job_id in experiment data path -- #TODO move into own routine in Storage.pm
CoGe::Accessory::TDS::write(
    catfile($storage_path, 'metadata.json'),
    {
        workflow_id => int($wid)
    }
);

# Create "log.done" file to indicate completion to JEX
touch($logdonefile);

exit;

#-------------------------------------------------------------------------------
sub detect_data_type {
    my $filetype = shift;
    my $filepath = shift;
    print STDOUT "detect_data_type: $filepath\n";

    if (!$filetype or $filetype eq 'autodetect') {
        # Try to determine type based on file extension
        #print STDOUT "log: Detecting file type\n";
        ($filetype) = lc($filepath) =~ /\.([^\.]+)$/;
    }
    
    $filetype = lc($filetype);

    if ( grep { $_ eq $filetype } @QUANT_TYPES ) {
        print STDOUT "log: Detected a quantitative file ($filetype)\n";
        return ($filetype, $DATA_TYPE_QUANT);
    }
    elsif ( $filetype eq 'bam' ) {
        print STDOUT "log: Detected an alignment file ($filetype)\n";
        return ($filetype, $DATA_TYPE_ALIGN);
    }
    elsif ( $filetype eq 'vcf' ) {
        print STDOUT "log: Detected a polymorphism file ($filetype)\n";
        return ($filetype, $DATA_TYPE_POLY);
    }
    elsif ( grep { $_ eq $filetype } @MARKER_TYPES ) {
        print STDOUT "log: Detected a marker file ($filetype)\n";
        return ($filetype, $DATA_TYPE_MARKER);
    }
    else {
        print STDOUT "detect_data_type: unknown file ext '$filetype'\n";
        return ($filetype);
    }
}

#TODO rewrite this to load the file once into memory rather than reading it twice
sub max_of_values {
	my $filepath = shift;
	my $filetype = shift;
	my $max = 0;
    open( my $in, $filepath ) || die "can't open $filepath for reading: $!";
    while ( my $line = <$in> ) {
        next if ( $line =~ /^\s*#/ ); # skip comment lines
        chomp $line;
        next unless $line; # skip blank lines
        # Interpret tokens according to file type
        my @tok;
        my ( $chr, $start, $stop, $strand, $val1, $val2, $label );
        if ($filetype eq 'csv') { # CoGe format, comma-separated
        	@tok = split( /,/, $line );
        	( $chr, $start, $stop, $strand, $val1, $val2 ) = @tok;
        }
        elsif ($filetype eq 'tsv') { # CoGe format, tab-separated
        	@tok = split( /\s+/, $line );
        	( $chr, $start, $stop, $strand, $val1, $val2 ) = @tok;
        }
        elsif ($filetype eq 'wig') {
     		my ($stepSpan, $stepChr, $line_num);
            next if ( $line =~ /^track/ ); # ignore "track" line
            if ( $line =~ /^variableStep/i ) { # handle step definition line
                if ($line =~ /chrom=(\w+)/i) {
                    $stepChr = $1;
                }
                
                $stepSpan = 1;
                if ($line =~ /span=(\d+)/i) {
                    $stepSpan = $1;
                }
                next;
            }
            elsif ( $line =~ /^fixedStep/i ) {
                log_line('fixedStep wiggle format is no currently supported', $line_num, $line);
                return;
            }
            
            if (not defined $stepSpan or not defined $stepChr) {
                log_line('missing or invalid wiggle step definition line', $line_num, $line);
                return;
            }
            
            @tok = split( /\s+/, $line );
            ( $start, $val1 ) = @tok;
        }
        elsif ($filetype eq 'bed') {
        	my $bedType;
            # Check for track type for BED files
            if ( $line =~ /^track/ ) {
                undef $bedType;
                if ($line =~ /type=(\w+)/i) {
                    $bedType = lc($1);
                }
                next;
            }
        
            # Handle different BED formats
            @tok = split( /\s+/, $line );
            if (defined $bedType && $bedType eq 'bedgraph') { # UCSC bedGraph: http://genome.ucsc.edu/goldenPath/help/bedgraph.html
                ( $chr, $start, $stop, $val1 ) = @tok;
            }
            else { # UCSC standard BED: http://genome.ucsc.edu/FAQ/FAQformat.html#format1
                ( $chr, $start, $stop, $label, $val1, $strand ) = @tok;
            }
        }
        else { # unknown file type (should never happen)
        	die "fatal error: unknown file type!";
        }
        if ($val1 > $max) {
	        $max = $val1;
        }
    }
    close($in);
    print STDOUT "max=$max\n";
    return $max;
 }

# Parses multiple line-based file formats for quant data
sub validate_quant_data_file { #TODO this routine is getting long, break into subroutines
    my %opts = @_;
    my $filepath = $opts{file};
    my $filetype = $opts{file_type};
    my $genome_chr = $opts{genome_chr};
    my %chromosomes;
    my $line_num = 0;
    my $count;
    my $hasLabels = 0;
    my $hasVal2   = 0;
    my $bedType; # only used for BED formats
    my ($stepSpan, $stepChr); # only used for WIG format

    print STDOUT "validate_quant_data_file: $filepath\n";
    my $max;
    if ($normalize) {
    	$max = max_of_values($filepath, $filetype);
    }
    open( my $in, $filepath ) || die "can't open $filepath for reading: $!";
    my $outfile = $filepath . ".processed";
    open( my $out, ">$outfile" );
    while ( my $line = <$in> ) {
        $line_num++;
        next if ( $line =~ /^\s*#/ ); # skip comment lines
        chomp $line;
        next unless $line; # skip blank lines
        
        # Interpret tokens according to file type
        my @tok;
        my ( $chr, $start, $stop, $strand, $val1, $val2, $label );
        if ($filetype eq 'csv') { # CoGe format, comma-separated
        	@tok = split( /,/, $line );
        	( $chr, $start, $stop, $strand, $val1, $val2 ) = @tok;
        }
        elsif ($filetype eq 'tsv') { # CoGe format, tab-separated
        	@tok = split( /\s+/, $line );
        	( $chr, $start, $stop, $strand, $val1, $val2 ) = @tok;
        }
        elsif ($filetype eq 'wig') {
            next if ( $line =~ /^track/ ); # ignore "track" line
            if ( $line =~ /^variableStep/i ) { # handle step definition line
                if ($line =~ /chrom=(\w+)/i) {
                    $stepChr = $1;
                }
                
                $stepSpan = 1;
                if ($line =~ /span=(\d+)/i) {
                    $stepSpan = $1;
                }
                next;
            }
            elsif ( $line =~ /^fixedStep/i ) {
                log_line('fixedStep wiggle format is no currently supported', $line_num, $line);
                return;
            }
            
            if (not defined $stepSpan or not defined $stepChr) {
                log_line('missing or invalid wiggle step definition line', $line_num, $line);
                return;
            }
            
            @tok = split( /\s+/, $line );
            ( $start, $val1 ) = @tok;
            $stop = $start + $stepSpan - 1;
            $chr = $stepChr;
            $strand = '.'; # determine strand by val1 polarity   
        }
        elsif ($filetype eq 'bed') {
            # Check for track type for BED files
            if ( $line =~ /^track/ ) {
                undef $bedType;
                if ($line =~ /type=(\w+)/i) {
                    $bedType = lc($1);
                }
                next;
            }
        
            # Handle different BED formats
            @tok = split( /\s+/, $line );
            if (defined $bedType && $bedType eq 'bedgraph') { # UCSC bedGraph: http://genome.ucsc.edu/goldenPath/help/bedgraph.html
                ( $chr, $start, $stop, $val1 ) = @tok;
                $strand = '.'; # determine strand by val1 polarity
            }
            else { # UCSC standard BED: http://genome.ucsc.edu/FAQ/FAQformat.html#format1
                ( $chr, $start, $stop, $label, $val1, $strand ) = @tok;
                $val2 = $tok[6] if (@tok >= 7); # non-standard CoGe usage
            }
            
            # Adjust coordinates from base-0 to base-1
            if (defined $start and defined $stop) {
                $start += 1;
                $stop += 1;
            }
        }
        else { # unknown file type (should never happen)
        	die "fatal error: unknown file type!";
        }

        # Validate mandatory fields
        if (   not defined $chr
            or not defined $start
            or not defined $stop
            or not defined $strand )
        {
            my $missing;
            $missing = 'chr'    unless $chr;
            $missing = 'start'  unless $start;
            $missing = 'stop'   unless $stop;
            $missing = 'strand' unless $strand;
            log_line("missing value in a column: $missing", $line_num, $line);
            return;
        }

        # mdb added 2/19/14 for bulk loading based on user request
        if ($allow_negative and $val1 < 0) {
	       $val1 = abs($val1);
        }
        # mdb added 3/13/14 issue 331 - set strand based on polarity of value
        elsif ($strand eq '.') {
            $strand = ($val1 >= 0 ? 1 : -1);
            $val1 = abs($val1);
        }
        if (!$normalize) {
        	if (not defined $val1 or (!$disable_range_check and ($val1 < 0 or $val1 > 1))) {
	            log_line('value 1 not between 0 and 1', $line_num, $line);
    	        return;
        	}
        }

        # Munge chr name for CoGe
        ($chr) = split(/\s+/, $chr);
		$chr = fix_chromosome_id($chr, $genome_chr);
        unless (defined $chr) {
            log_line("trouble parsing sequence ID", $line_num, $line);
            return;
        }
        $strand = $strand =~ /-/ ? -1 : 1;

        # Build output line
        if ($normalize) {
	        if ($normalize eq "percentage") {
	        	$val1 /= $max;
	        }
	        elsif ($normalize eq "log10") {
	        	$val1 = log($val1) / log(10) / $max;
	        }
	        else {
	        	$val1 = log($val1) / $max;
	        }
        }
        my @fields  = ( $chr, $start, $stop, $strand, $val1 ); # default fields
        if (defined $val2) {
            $hasVal2 = 1;
            push @fields, $val2;
        }
        if (defined $label) {
            $hasLabels = 1;
            push @fields, $label;
        }
        print $out join( ",", @fields ), "\n";

        # Keep track of seen chromosome names for later use
        $chromosomes{$chr}++;
        $count++;
    }
    close($in);
    close($out);

    #my $format = "chr:key, start:unsigned long, stop:unsigned long, strand:byte, value1:double, value2:double, label:text"; # mdb removed 4/2/14, issue 352
    # mdb added 4/2/14, issue 352
    my $format = {
        columns => [
            { name => 'chr',    type => 'key' },
            { name => 'start',  type => 'unsigned long' },
            { name => 'stop',   type => 'unsigned long' },
            { name => 'strand', type => 'byte' },
            { name => 'value1', type => 'double' }
        ]
    };
    push(@{$format->{columns}}, { name => 'value2', type => 'double' }) if $hasVal2;
    push(@{$format->{columns}}, { name => 'label',  type => 'text' }) if $hasLabels;

    return ( $outfile, $format, $count, \%chromosomes );
}

# For VCF format specification v4.1, see http://www.1000genomes.org/node/101
sub validate_vcf_data_file {
    my %opts       = @_;
    my $filepath   = $opts{file};
    my $genome_chr = $opts{genome_chr};

    my %chromosomes;
    my $line_num = 1;
    my $count;

    print STDOUT "validate_vcf_data_file: $filepath\n";
    open( my $in, $filepath ) || die "can't open $filepath for reading: $!";
    my $outfile = $filepath . ".processed";
    open( my $out, ">$outfile" );
    while ( my $line = <$in> ) {
        $line_num++;

		#TODO load VCF metadata for storage as experiment annotations in DB (lines that begin with '##')
        next if ( $line =~ /^#/ );
        chomp $line;
        next unless $line;
        my @tok = split( /\s+/, $line );

        # Validate format
        if ( @tok < $MIN_VCF_COLUMNS ) {
            log_line('more columns expected ('.@tok.' < '.$MIN_VCF_COLUMNS.')', $line_num, $line);
            return;
        }

        # Validate values and set defaults
        my ( $chr, $pos, $id, $ref, $alt, $qual, undef, $info ) = @tok;
        if (   not defined $chr
            || not defined $pos
            || not defined $ref
            || not defined $alt )
        {
            log_line('missing required value in a column', $line_num, $line);
            return;
        }
        next if ( $alt eq '.' );    # skip monomorphic sites
        $id   = '.' if ( not defined $id );
        $qual = 0   if ( not defined $qual );
        $info = ''  if ( not defined $info );

        $chr = fix_chromosome_id($chr, $genome_chr);
        if (!$chr) {
            log_line('trouble parsing chromosome', $line_num, $line);
            return;
        }
        $chromosomes{$chr}++;

        # Each line could encode multiple alleles
        my @alleles = split( ',', $alt );
        foreach my $a (@alleles) {
            # Determine site type
            my $type = detect_site_type( $ref, $a );

            # Save to file
            print $out join( ",",
                $chr, $pos, $pos + length($ref) - 1,
                $type, $id, $ref, $a, $qual, $info ),
              "\n";
            $count++;
        }
    }
    close($in);
    close($out);

    #my $format = "chr:key, start:unsigned long, stop:unsigned long, type:key, id:text, ref:key, alt:key, qual:double, info:text"; # mdb removed 4/2/14, issue 352
    # mdb added 4/2/14, issue 352
    my $format = {
        columns => [
            { name => 'chr',   type => 'key' },
            { name => 'start', type => 'unsigned long' },
            { name => 'stop',  type => 'unsigned long' },
            { name => 'type',  type => 'key' },
            { name => 'id',    type => 'text' },
            { name => 'ref',   type => 'key' },
            { name => 'alt',   type => 'key' },
            { name => 'qual',  type => 'double' }
            #{ name => 'info',  type => 'text' }
        ]
    };

    return ( $outfile, $format, $count, \%chromosomes );
}

sub detect_site_type {
    my $ref = shift;
    my $alt = shift;

    return 'snp' if ( length $ref == 1 and length($alt) == 1 );
    return 'deletion'  if ( length $ref > length $alt );
    return 'insertion' if ( length $ref < length $alt );
    return 'unknown';
}

sub validate_bam_data_file {
    my %opts       = @_;
    my $filepath   = $opts{file};
    my $genome_chr = $opts{genome_chr};

    my %chromosomes;
    my $count;

    print STDOUT "validate_bam_data_file: $filepath\n";

	# Get the number of reads in BAM file
	my $cmd = "$SAMTOOLS view -c $filepath";
	print STDOUT $cmd, "\n";
    my $cmdOut = qx{$cmd};
    if ( $? != 0 ) {
	    print STDOUT "log: error executing samtools view -c command: $?\n";
	    exit(-1);
	}
	if ($cmdOut =~ /\d+/) {
		$count = $cmdOut;
	}

	# Get the BAM file header
	$cmd = "$SAMTOOLS view -H $filepath";
	print STDOUT $cmd, "\n";
    my @header = qx{$cmd};
    #print STDOUT "Old header:\n", @header;
    execute($cmd);

	# Parse the chromosome names out of the header
	my %renamed;
	foreach (@header) {
		chomp;
		if ($_ =~ /^\@SQ\s+SN\:(\S+)/) {
			my $chr = $1;
			my $newChr = fix_chromosome_id($chr, $genome_chr);
			$renamed{$chr} = $newChr if ($newChr ne $chr);
			$chromosomes{$newChr}++;
		}
	}

	# Reheader the bam file if chromosome names changed
	my $newfilepath = "$staging_dir/alignment.bam";
	if (keys %renamed) {
		# Replace chromosome names in header
		my @header2;
		foreach my $line (@header) {
			my $match = qr/^(\@SQ\s+SN\:)(\S+)/;
			if ($line =~ $match) {
				my $newChr = $renamed{$2};
				$line =~ s/$match/$1$newChr/ if defined $newChr;
			}
			push @header2, $line."\n";
		}
		print STDOUT "New header:\n", @header2;

		# Write header to temp file
		my $header_file = "$staging_dir/header.txt";
		open( my $out, ">$header_file" );
		print $out @header2;
		close($out);

		# Run samtools to reformat the bam file header
		$cmd = "$SAMTOOLS reheader $header_file $filepath > $newfilepath";
		execute($cmd);

		# Remove the original bam file
		$cmd = "rm -f $filepath";
		execute($cmd);
	}
	elsif ($filepath ne $newfilepath) { # mdb added condition 3/12/15 -- possible that original file is named "alignment.bam"
		# Rename original bam file
		$cmd = "mv $filepath $newfilepath";
		execute($cmd);
	}
	
	# Sort the bam file
	# TODO this can be slow, is it possible to detect if it is sorted already?
	my $sorted_file = "$staging_dir/sorted";
    $cmd = "$SAMTOOLS sort $newfilepath $sorted_file";
    execute($cmd);
    if (-e "$sorted_file.bam" && -s "$sorted_file.bam" > 0) {
        # Replace original file with sorted version
        execute("mv $sorted_file.bam $newfilepath");
    }
    else {
        print STDOUT "log: error: samtools sort produced no result\n";
        exit(-1);
    }

	# Index the bam file
	$cmd = "$SAMTOOLS index $newfilepath";
	execute($cmd);

    return ( $newfilepath, undef, $count, \%chromosomes );
}

# http://www.sanger.ac.uk/resources/software/gff/spec.html
sub validate_gff_data_file {
    my %opts       = @_;
    my $filepath   = $opts{file};
    my $genome_chr = $opts{genome_chr};

    my %chromosomes;
    my $line_num = 1;
    my $count;

    print STDOUT "validate_gff_data_file: $filepath\n";
    open( my $in, $filepath ) || die "can't open $filepath for reading: $!";
    my $outfile = $filepath . ".processed";
    open( my $out, ">$outfile" );
    while ( my $line = <$in> ) {
        $line_num++;
        next if ( $line =~ /^#/ );
        chomp $line;
        next unless $line;
        my @tok = split( /\t/, $line );

        # Validate format
        if ( @tok < $MIN_GFF_COLUMNS ) {
            log_line("more columns expected (" . @tok . " < $MIN_GFF_COLUMNS)", $line_num, $line);
            return;
        }

        # Validate values and set defaults
        my ( $chr, $source, $type, $start, $stop, $score, $strand, $frame, $attr ) = @tok;
        if (   not defined $chr
            || not defined $type
            || not defined $start
            || not defined $stop )
        {
            log_line('missing required value in a column', $line_num, $line);
            return;
        }

        $chr = fix_chromosome_id($chr, $genome_chr);
        if (!$chr) {
            log_line('trouble parsing chromosome', $line_num, $line);
            return;
        }
        $chromosomes{$chr}++;

        $strand = (!defined $strand or $strand ne '-' ? 1 : -1);
        $score = 0 if (!defined $score || $score =~ /\D/);
        $attr = '' if (!defined $attr);

        print $out join(",", $chr, $start, $stop, $strand, $type, $score, $attr), "\n";
        $count++;
    }
    close($in);
    close($out);

    #my $format = "chr:key, start:unsigned long, stop:unsigned long, strand:key, type:key, score:double, attr:text"; # mdb removed 4/2/14, issue 352
    # mdb added 4/2/14, issue 352
    my $format = {
        columns => [
            { name => 'chr',    type => 'key' },
            { name => 'start',  type => 'unsigned long' },
            { name => 'stop',   type => 'unsigned long' },
            { name => 'strand', type => 'key' },
            { name => 'type',   type => 'key' },
            { name => 'score',  type => 'double' },
            { name => 'attr',   type => 'text' }
        ]
    };

    return ( $outfile, $format, $count, \%chromosomes );
}

sub execute { # FIXME move into Util.pm
    my $cmd = shift;
    print STDOUT "$cmd\n";
    my @cmdOut    = qx{$cmd};
    my $cmdStatus = $?;
    if ( $cmdStatus != 0 ) {
        print STDOUT "log: error: command failed with rc=$cmdStatus: $cmd\n";
        exit(-1);
    }
}

sub log_line {
    my ( $msg, $line_num, $line ) = @_;
    print STDOUT "log: error at line $line_num: $msg\n", "log: ", substr($line, 0, 100), "\n";    
}
