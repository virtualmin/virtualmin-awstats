#!/usr/local/bin/perl
# Refresh the AWstats report, from a cron job
use strict;
use warnings;

our $no_acl_check++;

require './virtualmin-awstats-lib.pl';

my $debug;
if ($ARGV[0] eq "--debug") {
	shift(@ARGV);
	$debug = 1;
	}
@ARGV == 1 || die "usage: awstats.pl [--debug] <domainname>";

if ($debug) {
	&generate_report($ARGV[0], *STDERR, 0);
	}
else {
	open(my $NULL, ">", "/dev/null");
	&generate_report($ARGV[0], $NULL, 0);
	close($NULL);
	}
