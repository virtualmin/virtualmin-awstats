#!/usr/local/bin/perl
# Show options for one AWstats domain

require './virtualmin-awstats-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
if ($in{'new'}) {
	$access{'create'} || &error($text{'edit_ecannot2'});
	&ui_print_header(undef, $text{'edit_title1'}, "");
	}
else {
	$conf = &get_config($in{'dom'});
	&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title2'}, "");
	}
$access{'editsched'} || &error($text{'edit_ecannot'});

print &ui_form_start("save.cgi", "post");
print &ui_table_start($text{'edit_header'}, "100%", 2);

if ($in{'new'}) {
	# Can enter domain name
	print &ui_table_row($text{'edit_dom'},
			    &ui_textbox("dom", undef, 40));
	print &ui_hidden("new", 1);
	}
else {
	# Just show domain name
	print &ui_table_row($text{'edit_dom'}, $in{'dom'});
	print &ui_hidden("dom", $in{'dom'});
	}

# Show log file (if editable)
$log = &find_value("LogFile", $conf);
if ($in{'new'} || $access{'editlog'}) {
	print &ui_table_row($text{'edit_log'}, 
			    &ui_textbox("log", $log, 50)." ".
			    &file_chooser_button("log", 0));
	}
else {
	print &ui_table_row($text{'edit_log'}, "<tt>$log</tt>");
	}

# Show log format
$format = &find_value("LogFormat", $conf);
$formatnum = $in{'new'} ? 4 : $format =~ /^\d+$/ ? $format : 0;
print &ui_table_row($text{'edit_format'},
	    &ui_select("format", $formatnum,
		[ map { [ $_, $text{'edit_format'.$_} ] } (1..4, 0) ])."<br>".
	    &ui_textbox("custom", $formatnum == 0 ? $format : undef, 50));

# Destination directory
$data = &find_value("DirData", $conf);
print &ui_table_row($text{'edit_data'},
		    &ui_textbox("data", $data, 40)."\n".
		    &file_chooser_button("data", 1));

# Run as user
$user = &get_run_user($in{'dom'});
if ($access{'user'} eq '*') {
	# Can select any user
	print &ui_table_row($text{'edit_user'},
			    &ui_user_textbox("user", $user));
	}
else {
	@users = split(/\s+/, $access{'user'});
	if (@users == 1) {
		# Cannot select any but one
		print &ui_table_row($text{'edit_user'}, "<tt>$users[0]</tt>");
		print &ui_hidden("user", $users[0]);
		}
	else {
		# Can select from several users
		print &ui_table_row($text{'edit_user'},
			&ui_select("user", $user,
				[ map { [ $_ ] } @users ]));
		}
	}

# Show section for schedule
print &ui_table_hr();
$job = &find_cron_job($in{'dom'});
print &ui_table_row($text{'edit_sched'},
		    &ui_radio("sched", $job ? 1 : 0,
			      [ [ 0, $text{'edit_sched0'} ],
				[ 1, $text{'edit_sched1'} ] ]));
print "<tr> <td colspan=2><table border width=100%>\n";
$job ||= { 'mins' => 0,
	   'hours' => 0,
	   'days' => '*',
	   'months' => '*',
	   'weekdays' => '*' };
&cron::show_times_input($job);
print "</table></td> </tr>\n";

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ],
			     [ "view", $text{'edit_view'} ],
			     [ "config", $text{'edit_config'} ],
			     [ "gen", $text{'edit_gen'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

