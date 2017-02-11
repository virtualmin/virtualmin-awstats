#!/usr/local/bin/perl
# Refresh the AWstats report
use strict;
use warnings;
our (%text, %in);

require './virtualmin-awstats-lib.pl';
&ReadParse();
&error_setup($text{'generate_err'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});

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
print "</pre>";
print(($ok ? &text('gen_done', "view.cgi?config=$in{'dom'}")
	   : $text{'gen_failed'}), "<p>\n");

&ui_print_footer("", $text{'index_return'});

