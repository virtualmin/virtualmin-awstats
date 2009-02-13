#!/usr/local/bin/perl
# Show a form for editing AWstats config file settings

require './virtualmin-awstats-lib.pl';
&ReadParse();
$conf = &get_config($in{'dom'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
&ui_print_header("<tt>$in{'dom'}</tt>", $text{'config_title'}, "");

print &ui_form_start("config_save.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_table_start($text{'config_header'}, "100%", 2);

# Do DNS lookups?
$dnslookup = &find_value("DNSLookup", $conf);
print &ui_table_row($text{'config_dnslookup'},
	&ui_select("dnslookup", $dnslookup,
		   [ [ '', $text{'default'} ],
		     [ 0, $text{'config_dnslookup0'} ],
		     [ 1, $text{'config_dnslookup1'} ],
		     [ 2, $text{'config_dnslookup2'} ] ]));

# Allow full-year view?
$year = &find_value("AllowFullYearView", $conf);
print &ui_table_row($text{'config_year'},
	&ui_select("year", $year,
		   [ [ '', $text{'default'} ],
                     [ 0, $text{'config_year0'} ],
                     [ 1, $text{'config_year1'} ],
                     [ 2, $text{'config_year2'} ],
                     [ 3, $text{'config_year3'} ] ]));

# Client hosts to skip
$skiphosts = &find_value("SkipHosts", $conf);
print &ui_table_row($text{'config_skiphosts'},
	&ui_opt_textbox("skiphosts", $skiphosts, 40, $text{'config_none'}));

# Browsers to skip
$skipagents = &find_value("SkipUserAgents", $conf);
print &ui_table_row($text{'config_skipagents'},
	&ui_opt_textbox("skipagents", $skipagents, 40, $text{'config_none'}));

# Files to skip
$skipfiles = &find_value("SkipFiles", $conf);
print &ui_table_row($text{'config_skipfiles'},
	&ui_opt_textbox("skipfiles", $skipfiles, 40, $text{'config_none'}));

# File types to exclude
# NotPageList

# HTTP codes to include
# ValidHTTPCodes

# Framed report UI
# UseFramesWhenCGI

print &ui_table_hr();

# Detection levels
# LevelForRobotsDetection
# LevelForBrowsersDetection
# LevelForOSDetection
# LevelForRefererAnalyze

print &ui_table_hr();

# Enabled plugins
# XXX

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
