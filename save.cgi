#!/usr/local/bin/perl
# Save options for one AWstats domain

require './virtualmin-awstats-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'save_err'});
if ($in{'new'}) {
	$access{'create'} || &error($text{'edit_ecannot2'});
	}
else {
	&can_domain($in{'dom'}) || &error($text{'edit_ecannot'});
	$oldjob = $job = &find_cron_job($in{'dom'});
	}
$access{'editsched'} || &error($text{'edit_ecannot'});

if ($in{'delete'}) {
	# Just delete awstats config and cron job
	$in{'dom'} eq 'model' && &error($text{'edit_emodel'});
	&delete_config($in{'dom'});
	&cron::delete_cron_job($job) if ($job);
	&redirect("");
	}
elsif ($in{'gen'}) {
	# Redirect to report generator
	&redirect("generate.cgi?dom=$in{'dom'}");
	}
elsif ($in{'view'}) {
	# Redirect to report viewer
	&redirect("view.cgi?config=$in{'dom'}");
	}
elsif ($in{'config'}) {
	# Redirect to awstats.conf page
	&redirect("config.cgi?dom=$in{'dom'}");
	}
else {
	# Validate inputs
	if ($in{'new'}) {
		$in{'dom'} =~ /^[a-z0-9\.\-\_]+$/i ||
			&error($text{'save_edom'});
		($clash) = grep { $_ eq $in{'dom'} } &list_configs();
		$clash && &error($text{'save_eclash'});
		}
	if ($in{'new'} || $access{'editlog'}) {
		-r $in{'log'} || $in{'log'} =~ /\%/ || $in{'log'} =~ /\|\s*$/ ||
			&error($text{'save_elog'});
		}
	if ($in{'format'} == 0) {
		$in{'other'} =~ /\%/ || &error($text{'save_eformat'});
		}
	-d $in{'data'} || &error($text{'save_edata'});
	if ($in{'sched'}) {
		$job ||= { 'user' => 'root',
			   'command' => "$cron_cmd $in{'dom'}",
			   'active' => 1 };
		&cron::parse_times_input($job, \%in);
		}
	defined(getpwnam($in{'user'})) || &error($text{'save_euser'});
	if ($access{'user'} ne '*') {
		@users = split(/\s+/, $access{'user'});
		&indexof($in{'user'}, @users) >= 0 ||
			&error($text{'save_euser2'});
		}

	if ($in{'new'}) {
		# Copy template conf file to new one
		$out = &backquote_logged("cp ".quotemeta(&awstats_model_file())." ".quotemeta("$config{'config_dir'}/awstats.$in{'dom'}.conf"));
		$? && &error(&text('save_ecopy', "<tt>$out</tt>"));
		}

	# Update the config file
	$conf = &get_config($in{'dom'});
	if ($in{'new'}) {
		&save_directive($conf, $in{'dom'}, "SiteDomain", $in{'dom'});
		&save_directive($conf, $in{'dom'}, "HostAliases", "www.$in{'dom'}");
		}
	if ($in{'new'} || $access{'editlog'}) {
		&save_directive($conf, $in{'dom'}, "LogFile", $in{'log'});
		}
	&save_directive($conf, $in{'dom'}, "LogFormat",
			$in{'format'} == 0 ? $in{'other'} : $in{'format'});
	&save_directive($conf, $in{'dom'}, "DirData", $in{'data'});
	&flush_file_lines();

	# Save the run-as user, and setup the cron job
	&save_run_user($in{'dom'}, $in{'user'});
	&cron::create_wrapper($cron_cmd, $module_name, "awstats.pl");
	if ($in{'sched'} && $oldjob) {
		# Just update job
		&cron::change_cron_job($job);
		}
	elsif ($in{'sched'} && !$oldjob) {
		# Add cron job
		&cron::create_cron_job($job);
		}
	elsif (!$in{'sched'} && $oldjob) {
		# Remove cron job
		&cron::delete_cron_job($job);
		}

	# Redirect appropriately
	if (&foreign_check("virtual-server")) {
		&foreign_require("virtual-server", "virtual-server-lib.pl");
		$d = &virtual_server::get_domain_by("dom", $in{'dom'});
		}
	if ($d) {
		&virtual_server::domain_redirect($d);
		}
	else {
		&redirect("");
		}
	}

