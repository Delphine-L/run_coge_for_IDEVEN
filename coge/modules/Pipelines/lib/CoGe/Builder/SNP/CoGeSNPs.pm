package CoGe::Builder::SNP::CoGeSNPs;

use v5.14;
use strict;
use warnings;

use Carp;
use Data::Dumper qw(Dumper);
use File::Basename qw(fileparse basename dirname);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile catdir);
use Getopt::Long qw(GetOptions);
use JSON qw(decode_json);
use URI::Escape::JavaScript qw(unescape);

use CoGe::Accessory::Workflow;
use CoGe::Accessory::Jex;
use CoGe::Accessory::Web qw(get_defaults get_job schedule_job);
use CoGe::Accessory::Utils qw(to_filename);
use CoGe::Core::Storage qw(get_genome_file get_workflow_paths);
use CoGe::Builder::CommonTasks;

BEGIN {
    use vars qw ($VERSION @ISA @EXPORT);
    require Exporter;

    $VERSION = 0.1;
    @ISA     = qw (Exporter);
    @EXPORT = qw( build run );
}

our $CONF = CoGe::Accessory::Web::get_defaults();
our $FASTA_CACHE_DIR;

sub run {
    my %opts = @_;
    my $user = $opts{user};
    my $genome = $opts{genome};
    my $input_file = $opts{input_file};
    my $metadata = $opts{metadata};
    croak "Missing parameters" unless ($user and $genome and $input_file and $metadata);

    # Connect to workflow engine and get an id
    my $jex = CoGe::Accessory::Jex->new( host => $CONF->{JOBSERVER}, port => $CONF->{JOBPORT} );
    unless (defined $jex) {
        return (undef, "Could not connect to JEX");
    }

    # Create the workflow
    my $workflow = $jex->create_workflow( name => 'Running the SNP-finder pipeline', init => 1 );

    # Setup log file, staging, and results paths
    my ($staging_dir, $result_dir) = get_workflow_paths( $user->name, $workflow->id );
    $workflow->logfile( catfile($result_dir, 'debug.log') );

    # Build the workflow
    my @tasks = build({
        user => $user,
        wid  => $workflow->id,
        genome => $genome,
        input_file => $input_file,
        metadata => $metadata,
    });
    $workflow->add_jobs(\@tasks);

    # Submit the workflow
    my $result = $jex->submit_workflow($workflow);
    if ($result->{status} =~ /error/i) {
        return (undef, "Could not submit workflow");
    }

    return ($result->{id}, undef);
}

sub build {
    my $opts = shift;

    # Required arguments
    my $genome = $opts->{genome};
    my $input_file = $opts->{input_file}; # path to bam file
    my $user = $opts->{user};
    my $wid = $opts->{wid};
    my $metadata = $opts->{metadata};
    my $params = $opts->{params};

    # Setup paths
    my $gid = $genome->id;
    my $fasta_file = get_genome_file($gid);
    my $reheader_fasta =  to_filename($fasta_file) . ".reheader.faa";
    
    my ($staging_dir, $result_dir) = get_workflow_paths($user->name, $wid);

    $FASTA_CACHE_DIR = catdir($CONF->{CACHEDIR}, $gid, "fasta");
    die "ERROR: CACHEDIR not specified in config" unless $FASTA_CACHE_DIR;

    # Build the workflow's tasks
    my @tasks;
    push @tasks, create_fasta_reheader_job(
        fasta => $fasta_file, 
        reheader_fasta => $reheader_fasta, 
        cache_dir => $FASTA_CACHE_DIR
    );
    
    push @tasks, create_fasta_index_job(
        fasta => catfile($FASTA_CACHE_DIR, $reheader_fasta), 
        cache_dir => $FASTA_CACHE_DIR
    );
    
    push @tasks, create_samtools_job(
        reheader_fasta => $reheader_fasta, 
        gid => $gid, 
        input_file => $input_file, 
        staging_dir => $staging_dir
    );
    
    my $load_vcf_task = create_load_vcf_job({
        username => $user->name,
        staging_dir => $staging_dir,
        result_dir => $result_dir,
        wid => $wid,
        gid => $gid,
        vcf => catfile($staging_dir, 'snps.vcf'),
        metadata => $metadata
    });
    push @tasks, $load_vcf_task;
    
    # Save outputs for retrieval by downstream tasks
    my @done_files = (
        $load_vcf_task->{outputs}->[1]
    );
    
    my %results = (
        metadata => generate_additional_metadata(),
        done_files => \@done_files
    );

    return (\@tasks, \%results);
}

sub create_samtools_job {
    my %opts = @_;

    # Required arguments
    my $reheader_fasta = $opts{reheader_fasta};
    my $gid = $opts{gid};
    my $bam_file = $opts{input_file};
    my $staging_dir = $opts{staging_dir};
    
    # Optional arguments
    my $params = $opts{params};
    my $min_read_depth   = $params->{'min-read-depth'} || 10;
    my $min_base_quality = $params->{'min-base-quality'} || 20;
    my $min_allele_freq  = $params->{'min-allele-freq'} || 0.1;
    my $min_allele_count = $params->{'min-allele-count'} || 4;
    my $scale            = $params->{scale} || 32;
    
    die "ERROR: SAMTOOLS not specified in config" unless $CONF->{SAMTOOLS};
    my $samtools = $CONF->{SAMTOOLS};
    
    die "ERROR: SCRIPTDIR not specified in config" unless $CONF->{SCRIPTDIR};
    my $filter_script = catfile($CONF->{SCRIPTDIR}, 'pileup_SNPs.pl');
    $filter_script .= ' min_read_depth=' . $min_read_depth;
    $filter_script .= ' min_base_quality=' . $min_base_quality;
    $filter_script .= ' min_allele_freq=' . $min_allele_freq;
    $filter_script .= ' min_allele_count=' . $min_allele_count;
    $filter_script .= ' quality_scale=' . $scale;
    
    my $output_name = 'snps.vcf';

    return {
        cmd => $samtools,
        script => undef,
        args => [
            ['mpileup', '', 0],
            ['-f', '', 0],
            ['', $reheader_fasta, 1],
            ['', $bam_file, 1],
            ['|', $filter_script, 0],
            ['>', $output_name,  0]
        ],
        inputs => [
            catfile($FASTA_CACHE_DIR, $reheader_fasta),
            catfile($FASTA_CACHE_DIR, $reheader_fasta) . '.fai',
            $bam_file
        ],
        outputs => [
            catfile($staging_dir, $output_name)
        ],
        description => "Identifying SNPs using the CoGe method ..."
    };
}

sub generate_additional_metadata {
    my $params = shift;
    my $min_read_depth   = $params->{'min-read-depth'} || 10;
    my $min_base_quality = $params->{'min-base-quality'} || 20;
    my $min_allele_freq  = $params->{'min-allele-freq'} || 0.1;
    my $min_allele_count = $params->{'min-allele-count'} || 4;
    my $scale            = $params->{scale} || 32;

    my @annotations = (
        qq{note|SNPs generated using CoGe method},
        qq{note|Minimum read depth of $min_read_depth},
        qq{note|Minimum high-quality (PHRED >= $min_base_quality) allele count of $min_allele_count, FASTQ encoding $scale},
        qq{note|Minimum allele frequency of } . $min_allele_freq * 100 . '%'
    );
    return \@annotations;
}

1;
