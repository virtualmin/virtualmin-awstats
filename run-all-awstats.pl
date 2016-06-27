#!/usr/local/bin/perl
# Run AWstats reports for all virtual servers
use strict;
use warnings;
our $module_name;
our $cron_cmd;

our $no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop (my $pwd = `pwd`);
$0 = "$pwd/run-all-awstats.pl";
require './virtualmin-awstats-lib.pl';
$< == 0 || die "run-all-awstats.pl must be run as root";

&foreign_require("cron", "cron-lib.pl");
&foreign_require("virtual-server", "virtual-server-lib.pl");
&cron::create_wrapper($cron_cmd, $module_name, "awstats.pl");
foreach my $d (&virtual_server::list_domains()) {
	next if (!$d->{$module_name});
	print "Running AWstats for $d->{'dom'}\n";
	system("$cron_cmd $d->{'dom'}");
	}

