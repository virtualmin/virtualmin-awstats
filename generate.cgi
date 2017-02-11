#!/usr/local/bin/perl
# Refresh the AWstats report
use strict;
use warnings;
our (%text, %in);

require './virtualmin-awstats-lib.pl';
&ReadParse();
&error_setup($text{'generate_err'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});

&ui_print_unbuffered_header(undef, $text{'gen_title'}, "");

my $conf = &get_config($in{'dom'});
my $log = &find_value("LogFile", $conf);
my $data = &find_value("DirData", $conf);
if ($in{'wipe'} && $data) {
	print &text('gen_wiping', "<tt>".&html_escape($data)."</tt>"),"<br>\n";
	my $c = &clear_data_directory($in{'dom'}, $data);
	print &text('gen_wipedone', $c),"<p>\n";
	}

print &text('gen_doing', "<tt>$in{'dom'}</tt>", "<tt>$log</tt>"),"<br>\n";
print "<pre>";
my $ok = &generate_report($in{'dom'}, *STDOUT, 1);
if ($ok && !$d->{'web'}) {
	# Also re-generate static HTML
	my $outdir = &virtual_server::public_html_dir($d)."/awstats";
	&generate_html($in{'dom'}, $outdir);
	}
print "</pre>";
print(($ok ? &text('gen_done', "view.cgi?config=$in{'dom'}")
	   : $text{'gen_failed'}), "<p>\n");

&ui_print_footer("", $text{'index_return'});

