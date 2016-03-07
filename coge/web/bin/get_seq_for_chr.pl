#!/usr/bin/perl -w

use strict;
use CoGe::Accessory::Web;
use Data::Dumper;
use File::Spec::Functions;
use CGI;

my $q = CGI->new;
my $gid = $q->param('gid');
my $chr = $q->param('chr');

# Connect to the database
my $conf = CoGe::Accessory::Web->get_defaults();

my $filename = $gid . "_" . $chr . ".faa";

print "Content-Type: application/force-download\n";
print "Content-disposition: attachement; filename=chromosome_";
print $filename;
print "\n\n";

print ">chromosome " . $chr . "\n";

my $path = catfile($conf->{SECTEMPDIR}, "GenomeInfo/downloads", $gid);
my $file = catfile($path, $filename);
open(my $fh, $file);
while (my $l = <$fh>) {
  print $l;
}
close $fh;