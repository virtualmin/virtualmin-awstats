#!/usr/local/bin/perl
# Refresh the AWstats report, from a cron job
use strict;
use warnings;

our $no_acl_check++;

require './virtualmin-awstats-lib.pl';

my $debug;
if ($ARGV[0] eq "--debug") {
	# Enable debug mode, which shows the output from the report command
	shift(@ARGV);
	$debug = 1;
	}
if ($ARGV[0] eq "--output") {
	# Write a static HTML report to the given directory
	shift(@ARGV);
	$output = shift(@ARGV);
	-d $output || die "Missing directory $output";
	}
@ARGV == 1 || die "usage: awstats.pl [--debug] [--output dir] <domainname>";
$dname = shift(@ARGV);

if ($debug) {
	&generate_report($ARGV[0], *STDERR, 0);
	}
else {
	open(my $NULL, ">", "/dev/null");
	&generate_report($ARGV[0], $NULL, 0);
	close($NULL);
	}
if ($output) {
	&generate_html($dname, $output);
	}
