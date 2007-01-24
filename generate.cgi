#!/usr/local/bin/perl
# Refresh the AWstats report

require './virtualmin-awstats-lib.pl';
&ReadParse();
&error_setup($text{'generate_err'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});

&ui_print_unbuffered_header(undef, $text{'gen_title'}, "");

$conf = &get_config($in{'dom'});
$log = &find_value("LogFile", $conf);
print &text('gen_doing', "<tt>$in{'dom'}</tt>", "<tt>$log</tt>"),"<br>\n";
print "<pre>";
$ok = &generate_report($in{'dom'}, STDOUT, 1);
print "</pre>";
print ($ok ? &text('gen_done', "view.cgi?config=$in{'dom'}")
	   : $text{'gen_failed'}),"<p>\n";

&ui_print_footer("", $text{'index_return'});

