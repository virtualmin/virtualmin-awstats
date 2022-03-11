#!/usr/local/bin/perl
# Refresh the AWStats report
use strict;
use warnings;
our (%text, %in);

require './virtualmin-awstats-lib.pl';
&ReadParse();
&error_setup($text{'generate_err'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
&foreign_require("virtual-server");
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});

&ui_print_unbuffered_header(undef, $text{'gen_title'}, "", undef, undef, $in{'linked'} ? 1 : 0);

my $conf = &get_config($in{'dom'});
my $log = &find_value("LogFile", $conf);
my $data = &find_value("DirData", $conf);
if ($in{'wipe'} && $data) {
	print &text('gen_wiping', "<tt>".&html_escape($data)."</tt>"),"<br>\n";
	my $c = &clear_data_directory($in{'dom'}, $data);
	print &text('gen_wipedone', $c),"\n";
	print "$text{'gen_just_done'}<br>\n";
	}

print &text('gen_doing', "<tt>$in{'dom'}</tt>", "<tt>$log</tt>"),"<br>\n";
print "<pre>";
my $ok = &generate_report($in{'dom'}, *STDOUT, 1);
if ($ok && !&virtual_server::domain_has_website($d)) {
	# Also re-generate static HTML
	my $outdir = &virtual_server::public_html_dir($d)."/awstats";
	&generate_html($in{'dom'}, $outdir);
	}
print "</pre>";
print(($ok ? ("<p></p> ".&text('gen_done', "view.cgi?config=$in{'dom'}"))
	   : "$text{'gen_failed'}"), "<p>\n");


!$in{'linked'} && &ui_print_footer("", $text{'index_return'});