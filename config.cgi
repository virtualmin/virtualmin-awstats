#!/usr/local/bin/perl
# Show a form for editing AWStats config file settings
use strict;
use warnings;
our (%text, %in);

require './virtualmin-awstats-lib.pl';
&ReadParse();
my $conf = &get_config($in{'dom'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
my $d;
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	$d = &virtual_server::get_domain_by("dom", $in{'dom'});
	}
&ui_print_header($d ? &virtual_server::domain_in($d) : undef,
		 $text{'config_title'}, "", undef, undef, $in{'linked'} ? 1 : undef);

print &ui_form_start("config_save.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden_table_start($text{'config_header'}, "width=100%", 2,
			     "main", 1);

# Do DNS lookups?
my $dnslookup = &find_value("DNSLookup", $conf);
print &ui_table_row($text{'config_dnslookup'},
	&ui_select("dnslookup", $dnslookup,
		   [ [ '', $text{'default'} ],
		     [ 0, $text{'config_dnslookup0'} ],
		     [ 1, $text{'config_dnslookup1'} ],
		     [ 2, $text{'config_dnslookup2'} ] ]));

# Allow full-year view?
my $year = &find_value("AllowFullYearView", $conf);
print &ui_table_row($text{'config_year'},
	&ui_select("year", $year,
		   [ [ '', $text{'default'} ],
                     [ 0, $text{'config_year0'} ],
                     [ 1, $text{'config_year1'} ],
                     [ 2, $text{'config_year2'} ],
                     [ 3, $text{'config_year3'} ] ]));

# Client hosts to skip
my $skiphosts = &find_value("SkipHosts", $conf);
print &ui_table_row($text{'config_skiphosts'},
	&ui_opt_textbox("skiphosts", $skiphosts, 40, $text{'config_none'}));

# Browsers to skip
my $skipagents = &find_value("SkipUserAgents", $conf);
print &ui_table_row($text{'config_skipagents'},
	&ui_opt_textbox("skipagents", $skipagents, 40, $text{'config_none'}));

# Files to skip
my $skipfiles = &find_value("SkipFiles", $conf);
print &ui_table_row($text{'config_skipfiles'},
	&ui_radio("skipfiles_def", $skipfiles ? 0 : 1,
		  [ [ 1, $text{'config_none'} ],
		    [ 0, $text{'config_below'} ] ])."<br>\n".
	&ui_textarea("skipfiles", join("\n", split(/\s+/, $skipfiles)),
		     5, 60));

# File types to exclude
my $notpage = &find_value("NotPageList", $conf);
print &ui_table_row($text{'config_notpage'},
	&ui_opt_textbox("notpage", $notpage, 60,
	    $text{'default'}." (css js class gif jpg jpeg png bmp ico)<br>"));

# HTTP codes to include
my $httpcodes = &find_value("ValidHTTPCodes", $conf);
print &ui_table_row($text{'config_httpcodes'},
	&ui_opt_textbox("httpcodes", $httpcodes, 40,
		$text{'default'}." (200 304)"));

# Framed report UI
my $frames = &find_value("UseFramesWhenCGI", $conf);
print &ui_table_row($text{'config_frames'},
	&ui_select("frames", $frames,
		   [ [ undef, $text{'default'} ],
		     [ 0, $text{'no'} ],
		     [ 1, $text{'yes'} ] ]));

print &ui_table_hr();

# Detection levels
foreach my $dt ("LevelForRobotsDetection", "LevelForBrowsersDetection",
	        "LevelForOSDetection", "LevelForRefererAnalyze") {
	my $v = &find_value($dt, $conf);
	my $n = lc($dt); $n =~ s/^LevelFor//i;
	print &ui_table_row($text{'config_'.$n},
		&ui_select($n, $v, [ [ '', $text{'default'} ],
				     [ 0, $text{'config_level0'} ],
				     [ 1, $text{'config_level1'} ],
				     [ 2, $text{'config_level2'} ] ]));
	}

print &ui_hidden_table_end();

# Enabled plugins
my @plugins = &find_values("LoadPlugin", $conf);
my @allplugins = &list_all_plugins();
if (@allplugins) {
	print &ui_hidden_table_start($text{'config_plugins'}, "width=100%",
				     2, "plugins", 0);
	my @table = ( );
	foreach my $p (@allplugins) {
		push(@table, [
			{ 'type' => 'checkbox', 'name' => 'p',
			  'value' => $p,
			  'checked' => &indexof($p, @plugins) >= 0 },
			$p,
			&get_plugin_desc($p),
			]);
		}
	print &ui_table_row(undef, 
		&ui_columns_table([ $text{'config_penabled'},
				    $text{'config_pname'},
                                    $text{'config_pdesc'} ],
				  "100%", \@table), 2);
	print &ui_hidden_table_end();
	}

print &ui_submit($text{'save'});
print &ui_submit($text{'config_regen'}, 'gen');
print "&nbsp;&nbsp;" . &ui_checkbox('wipe', 1, $text{'config_wipe'}, 0);
print &ui_hidden("linked", $in{'linked'} ? 1 : 0);
print &ui_form_end();

!$in{'linked'} && &ui_print_footer("", $text{'index_return'});
