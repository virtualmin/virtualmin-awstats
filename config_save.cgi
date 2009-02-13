#!/usr/local/bin/perl
# Save AWstats config settings

require './virtualmin-awstats-lib.pl';
&ReadParse();
$conf = &get_config($in{'dom'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});

# Validate and store inputs
$cfile = &get_config_file($in{'dom'});
&lock_file($cfile);

# Do DNS lookups?
&save_directive($conf, $in{'dom'}, "DNSLookup", $in{'dnslookup'});

&flush_file_lines($cfile);
&unlock_file($cfile);
&webmin_log("config", "dom", $in{'dom'});

# Show post-save page
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
if ($d) {
	&virtual_server::domain_redirect($d);
	}
else {
	&redirect("");
	}

