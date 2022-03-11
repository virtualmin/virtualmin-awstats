#!/usr/local/bin/perl
# Save AWstats config settings
use strict;
use warnings;
our (%text, %in);

require './virtualmin-awstats-lib.pl';
&ReadParse();
my $conf = &get_config($in{'dom'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});

# Validate and store inputs
my $cfile = &get_config_file($in{'dom'});
&lock_file($cfile);

# Do DNS lookups?
&save_directive($conf, $in{'dom'}, "DNSLookup", $in{'dnslookup'});

# Allow full-year view?
&save_directive($conf, $in{'dom'}, "AllowFullYearView", $in{'year'});

# Client hosts to skip
&save_directive($conf, $in{'dom'}, "SkipHosts",
		$in{'skiphosts_def'} ? undef : $in{'skiphosts'});

# Browsers to skip
&save_directive($conf, $in{'dom'}, "SkipUserAgents",
		$in{'skipagents_def'} ? undef : $in{'skipagents'});

# Files to skip
$in{'skipfiles'} =~ s/\r?\n/ /g;
&save_directive($conf, $in{'dom'}, "SkipFiles",
		$in{'skipfiles_def'} ? undef : $in{'skipfiles'});

# File types to exclude
&save_directive($conf, $in{'dom'}, "NotPageList",
		$in{'notpage_def'} ? undef : $in{'notpage'});

# HTTP codes to include
&save_directive($conf, $in{'dom'}, "ValidHTTPCodes",
		$in{'httpcodes_def'} ? undef : $in{'httpcodes'});

# Framed report UI
&save_directive($conf, $in{'dom'}, "UseFramesWhenCGI", $in{'frames'});

# Detection levels
foreach my $dt ("LevelForRobotsDetection", "LevelForBrowsersDetection",
	     "LevelForOSDetection", "LevelForRefererAnalyze") {
	my $n = lc($dt); $n =~ s/^LevelFor//i;
	&save_directive($conf, $in{'dom'}, $dt, $in{$n});
	}

# Save plugins, if any
my @allplugins = &list_all_plugins();
if (@allplugins) {
	&save_directives($conf, $in{'dom'}, "LoadPlugin",
			 [ split(/\0/, $in{'p'}) ]);
	}

&flush_file_lines($cfile);
&unlock_file($cfile);
&webmin_log("config", "dom", $in{'dom'});

# Show post-save page
my $d;
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	$d = &virtual_server::get_domain_by("dom", $in{'dom'});
	}
if ($in{'gen'}) {	
	&redirect("generate.cgi?dom=".&urlize($in{'dom'}).
			      "&wipe=".&urlize($in{'wipe'}).
			      "&linked=".&urlize($in{'linked'}));
	}
elsif ($d) {
	&virtual_server::domain_redirect($d);
	}
else {
	&redirect("");
	}

