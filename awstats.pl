#!/usr/local/bin/perl
# Refresh the AWstats report, from a cron job

$no_acl_check++;
require './virtualmin-awstats-lib.pl';

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
	&generate_report($dname, STDERR, 0);
	}
else {
	open(NULL, ">/dev/null");
	&generate_report($dname, NULL, 0);
	close(NULL);
	}
if ($output) {
	&generate_html($dname, $output);
	}
