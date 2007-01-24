#!/usr/local/bin/perl
# Show all damains for which awstats is enabled, plus their schedules

require './virtualmin-awstats-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Make sure it is installed
$err = &check_awstats();
if ($err) {
	print $err,"\n";
	print &text('index_econfig', "../config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"awstats", $text{'index_awstats'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Find and show domains
@alldoms = &list_configs();
@doms = grep { &can_domain($_) } @alldoms;
if (@doms) {
	print "<a href='edit.cgi?new=1'>$text{'index_add'}</a><br>\n"
		if ($access{'create'});
	print &ui_columns_start([ $text{'index_dom'},
				  $text{'index_log'},
				  $text{'index_sched'},
				  $text{'index_report'} ]);
	foreach $d (sort { $a cmp $b } @doms) {
		$conf = &get_config($d);
		$log = &find_value("LogFile", $conf);
		$job = &find_cron_job($d);
		print &ui_columns_row([
			$access{'editsched'} ?
				"<a href='edit.cgi?dom=$d'>$d</a>" : $d,
			$log,
			$job ? &text('index_yes', &cron::when_text($job))
			     : $text{'index_no'},
			"<a href='view.cgi?config=$d'>$text{'index_view'}</a>"
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print "<a href='edit.cgi?new=1'>$text{'index_add'}</a><br>\n"
	if ($access{'create'});

&ui_print_footer("/", $text{'index'});

