#!/usr/local/bin/perl
# Show a form for editing AWstats config file settings

require './virtualmin-awstats-lib.pl';
&ReadParse();
$conf = &get_config($in{'dom'});
&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	$d = &virtual_server::get_domain_by("dom", $in{'dom'});
	}
&ui_print_header($d ? &virtual_server::domain_in($d) : undef,
		 $text{'config_title'}, "");

print &ui_form_start("config_save.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_hidden_table_start($text{'config_header'}, "width=100%", 2,
			     "main", 1);

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
$notpage = &find_value("NotPageList", $conf);
print &ui_table_row($text{'config_notpage'},
	&ui_opt_textbox("notpage", $notpage, 40,
		$text{'default'}." (css js class gif jpg jpeg png bmp ico)"));

# HTTP codes to include
$httpcodes = &find_value("ValidHTTPCodes", $conf);
print &ui_table_row($text{'config_httpcodes'},
	&ui_opt_textbox("httpcodes", $httpcodes, 40,
		$text{'default'}." (200 304)"));

# Framed report UI
$frames = &find_value("UseFramesWhenCGI", $conf);
print &ui_table_row($text{'config_frames'},
	&ui_select("frames", $frames,
		   [ [ undef, $text{'default'} ],
		     [ 0, $text{'no'} ],
		     [ 1, $text{'yes'} ] ]));

print &ui_table_hr();

# Detection levels
foreach $dt ("LevelForRobotsDetection", "LevelForBrowsersDetection",
	     "LevelForOSDetection", "LevelForRefererAnalyze") {
	$v = &find_value($dt, $conf);
	$n = lc($dt); $n =~ s/^LevelFor//i;
	print &ui_table_row($text{'config_'.$n},
		&ui_select($n, $v, [ [ '', $text{'default'} ],
				     [ 0, $text{'config_level0'} ],
				     [ 1, $text{'config_level1'} ],
				     [ 2, $text{'config_level2'} ] ]));
	}

print &ui_hidden_table_end();

# Enabled plugins
@plugins = &find_values("LoadPlugin", $conf);
@allplugins = &list_all_plugins();
if (@allplugins) {
	print &ui_hidden_table_start($text{'config_plugins'}, "width=100%",
				     2, "plugins", 0);
	@table = ( );
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

print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'gen', $text{'config_regen'} ] ]);

&ui_print_footer("", $text{'index_return'});
