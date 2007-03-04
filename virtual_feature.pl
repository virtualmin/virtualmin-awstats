# Defines functions for this feature

require 'virtualmin-awstats-lib.pl';

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disname'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
return $text{'feat_label'};
}

# feature_check()
# Returns undef if all the needed programs for this feature are installed,
# or an error message if not
sub feature_check
{
return &check_awstats();
}

# feature_depends(&domain)
# Returns undef if all pre-requisite features for this domain are enabled,
# or an error message if not
sub feature_depends
{
return $text{'feat_edepweb'} if (!$_[0]->{'web'});
return $text{'feat_edepunix'} if (!$_[0]->{'unix'} && !$_[0]->{'parent'});
return $text{'feat_edepdir'} if (!$_[0]->{'dir'});
return undef;
}

# feature_clash(&domain, [field])
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
if (!$_[1] || $_[1] eq 'dom') {
	return -r "$config{'config_dir'}/awstats.$_[0]->{'dom'}.conf" ?
		$text{'feat_clash'} : undef;
	}
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
local ($parentdom, $aliasdom, $subdom) = @_;
return $aliasdom || $subdom ? 0 : 1;	# not for alias or sub domains
}

sub feature_import
{
return -r "$config{'config_dir'}/awstats.$_[0]->{'dom'}.conf" ? 1 : 0;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
&$virtual_server::first_print($text{'feat_setup'});

# Copy the template config file
local $out = &backquote_logged("cp ".quotemeta(&awstats_model_file())." ".quotemeta("$config{'config_dir'}/awstats.$_[0]->{'dom'}.conf"));
if ($?) {
	&$virtual_server::second_print(&text('save_ecopy', "<tt>$out</tt>"));
	return 0;
	}

# Copy awstats.pl to the cgi-bin directory
local $cgidir = &get_cgidir($_[0]);
if (defined(&virtual_server::run_as_domain_user)) {
	&virtual_server::run_as_domain_user($_[0],
		"cp ".quotemeta($config{'awstats'})." ".quotemeta($cgidir));
	if ($?) {
		&$virtual_server::second_print(&text('save_ecopy2',
						     "<tt>$out</tt>"));
		return 0;
		}
	}
else {
	&system_logged("cp ".quotemeta($config{'awstats'})." ".quotemeta($cgidir));
	&system_logged("chown $_[0]->{'uid'}:$_[0]->{'ugid'} ".
	       quotemeta("$cgidir/awstats.pl"));
	}

# Create report directory
local $dir = "$_[0]->{'home'}/awstats";
&make_dir($dir, 0755);
&set_ownership_permissions($_[0]->{'uid'}, $_[0]->{'ugid'}, 0755, $dir);

# Work out the log format
local ($virt, $vconf) = &virtual_server::get_apache_virtual($_[0]->{'dom'}, $_[0]->{'web_port'});
local $clog = &apache::find_directive("CustomLog", $vconf);
local $fmt = $config{'format'} ? $config{'format'}
			       : $clog =~ /combined$/i ? 1 : 4;

# Update settings to match server
&lock_file(&get_config_file($_[0]->{'dom'}));
local $conf = &get_config($_[0]->{'dom'});
&save_directive($conf, $_[0]->{'dom'}, "SiteDomain", "\"$_[0]->{'dom'}\"");
local $qd = quotemeta($_[0]->{'dom'});
local $aliases = &virtual_server::substitute_template($config{'aliases'},$_[0]);
&save_directive($conf, $_[0]->{'dom'}, "HostAliases",
		"REGEX[$qd\$] $aliases");
&save_directive($conf, $_[0]->{'dom'}, "LogFile",
	&virtual_server::get_apache_log($_[0]->{'dom'}, $_[0]->{'web_port'}));
&save_directive($conf, $_[0]->{'dom'}, "DirData", $dir);
&save_directive($conf, $_[0]->{'dom'}, "LogFormat", $fmt);
&flush_file_lines();
&unlock_file(&get_config_file($_[0]->{'dom'}));

# Symlink www.domain file to domain
&symlink_logged(&get_config_file($_[0]->{'dom'}),
		&get_config_file("www.".$_[0]->{'dom'}));

# Set up cron job
&foreign_require("cron", "cron-lib.pl");
&save_run_user($_[0]->{'dom'}, $_[0]->{'user'});
if (!$config{'nocron'}) {
	local $job = { 'user' => 'root',
		       'command' => "$cron_cmd $_[0]->{'dom'}",
		       'active' => 1,
		       'mins' => int(rand()*60),
		       'hours' => int(rand()*6),
		       'days' => '*',
		       'months' => '*',
		       'weekdays' => '*' };
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
&cron::create_wrapper($cron_cmd, $module_name, "awstats.pl");

# Create symlinks to other directories in source dir
foreach my $dir ("lib", "lang", "plugins") {
	local $src;
	if ($config{$dir}) {
		$src = $config{$dir};
		}
	else {
		$config{'awstats'} =~ /^(.*)\//;
		$src = $1;
		}
	$src .= "/$dir" if ($dir !~ /\/\Q$dir\E$/);
	&symlink_logged($src, "$cgidir/$dir");
	}

# Create symlink to icons directory
local $htmldir = &get_htmldir($_[0]);
if (!-d "$htmldir/icon") {
	&symlink_logged($config{'icons'}, "$htmldir/icon");
	}

# Add script alias to make /awstats/awstats.pl work
foreach my $port ($_[0]->{'web_port'},
		  $_[0]->{'ssl'} ? ( $_[0]->{'web_sslport'} ) : ( )) {
	local ($virt, $vconf) = &virtual_server::get_apache_virtual(
					$_[0]->{'dom'}, $port);
	if ($virt) {
		local $conf = &apache::get_config();
		local @sa = &apache::find_directive("ScriptAlias", $vconf);
		local ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
		if (!$aw) {
			# Need to add
			&lock_file($virt->{'file'});
			push(@sa, "/awstats $cgidir");
			&apache::save_directive("ScriptAlias", \@sa,
						$vconf, $conf);
			&flush_file_lines();
			&unlock_file($virt->{'file'});
			&virtual_server::register_post_action(
				\&virtual_server::restart_apache);
			}
		}
	}

&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
if ($_[0]->{'dom'} ne $_[1]->{'dom'}) {
	# Domain has been re-named .. rename awstats config
	&$virtual_server::first_print($text{'feat_modify'});
	local $oldfile = &get_config_file($_[1]->{'dom'});
	local $newfile = &get_config_file($_[0]->{'dom'});
	&rename_logged($oldfile, $newfile);
	&unlink_logged(&get_config_file("www.".$_[1]->{'dom'}));
	&symlink_logged(&get_config_file($_[0]->{'dom'}),
			&get_config_file("www.".$_[0]->{'dom'}));

	# Update hostname in file
	&lock_file($newfile);
	local $conf = &get_config($_[0]->{'dom'});
	foreach my $d ("SiteDomain", "HostAliases") {
		local $v = &find_value($d, $conf);
		$v =~ s/$_[1]->{'dom'}/$_[0]->{'dom'}/g;
		&save_directive($conf, $_[0]->{'dom'}, $d, $v);
		}
	&flush_file_lines();
	&unlock_file($newfile);
	&foreign_require("cron", "cron-lib.pl");
	local $job = &find_cron_job($_[1]->{'dom'});
	if ($job) {
		&lock_file(&cron::cron_file($job));
		$job->{'command'} = "$cron_cmd $_[0]->{'dom'}";
		&cron::change_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'user'} ne $_[1]->{'user'}) {
	# Username has changed .. update run-as user
	&$virtual_server::first_print($text{'feat_modifyuser'});
	&save_run_user($_[0]->{'dom'}, $_[0]->{'user'});
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'home'} ne $_[1]->{'home'}) {
	# Home directory has changed .. update log and data dirs
	&$virtual_server::first_print($text{'feat_modifyhome'});
	&lock_file(&get_config_file($_[0]->{'dom'}));
	local $conf = &get_config($_[0]->{'dom'});
	local $dir = "$_[0]->{'home'}/awstats";
	&save_directive($conf, $_[0]->{'dom'}, "DirData", $dir);
	&save_directive($conf, $_[0]->{'dom'}, "LogFile",
		&virtual_server::get_apache_log($_[0]->{'dom'},
					        $_[0]->{'web_port'}));
	&flush_file_lines();
	&unlock_file(&get_config_file($_[0]->{'dom'}));
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
return 1;
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
# Delete config and cron job
&$virtual_server::first_print($text{'feat_delete'});
&foreign_require("cron", "cron-lib.pl");
local $job = &find_cron_job($_[0]->{'dom'});
if ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
&delete_config($_[0]->{'dom'});

# Delete awstats.pl from the cgi-bin directory
local $cgidir = &get_cgidir($_[0]);
&unlink_logged("$cgidir/awstats.pl");

# Delete symlinks
local $cgidir = &get_cgidir($_[0]);
foreach my $dir ("lib", "lang", "plugins") {
	if (-l "$cgidir/$dir") {
		&unlink_logged("$cgidir/$dir");
		}
	}
local $htmldir = &get_htmldir($_[0]);
if (-l "$htmldir/icon") {
	&unlink_logged("$htmldir/icon");
	}

# Remove script alias for /awstats
foreach my $port ($_[0]->{'web_port'},
		  $_[0]->{'ssl'} ? ( $_[0]->{'web_sslport'} ) : ( )) {
	local ($virt, $vconf) = &virtual_server::get_apache_virtual(
					$_[0]->{'dom'}, $port);
	if ($virt) {
		local $conf = &apache::get_config();
		local @sa = &apache::find_directive("ScriptAlias", $vconf);
		local ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
		if ($aw) {
			# Need to remove
			&lock_file($virt->{'file'});
			@sa = grep { $_ ne $aw } @sa;
			&apache::save_directive("ScriptAlias", \@sa,
						$vconf, $conf);
			&flush_file_lines();
			&unlock_file($virt->{'file'});
			&virtual_server::register_post_action(
				\&virtual_server::restart_apache);
			}
		}
	}

&$virtual_server::second_print($virtual_server::text{'setup_done'});
}

# feature_webmin(&domain, &other)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
local @doms = map { $_->{'dom'} } grep { $_->{$module_name} } @{$_[1]};
if (@doms) {
	return ( [ $module_name,
		   { 'create' => 0,
		     'user' => $_[0]->{'user'},
		     'editlog' => 0,
		     'editsched' => !$config{'noedit'},
		     'domains' => join(" ", @doms),
		     'noconfig' => 1,
		   } ] );
	}
else {
	return ( );
	}
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
local ($d) = @_;
return ( { 'mod' => $module_name,
           'desc' => $access{'editsched'} ? $text{'links_link'}
					  : $text{'links_view'},
           'page' => $access{'editsched'} ?
			'edit.cgi?dom='.&urlize($d->{'dom'}) :
			'view.cgi?config='.&urlize($d->{'dom'}),
	   'cat' => 'logs',
         } );
}

# feature_backup(&domain, file, &opts, &all-opts)
# Copy the awstats config file for the domain
sub feature_backup
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_backup'});
local $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
if (-r $cfile) {
	&copy_source_dest($cfile, $file);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
else {
	&$virtual_server::second_print($text{'feat_nofile'});
	return 0;
	}
}

# feature_restore(&domain, file, &opts, &all-opts)
# Called to restore this feature for the domain from the given file
sub feature_restore
{
local ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_restore'});
local $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
&lock_file($cfile);
if (&copy_source_dest($file, $cfile)) {
	&unlock_file($cfile);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
else {
	&$virtual_server::second_print($text{'feat_nocopy'});
	return 0;
	}
}

sub feature_backup_name
{
return $text{'feat_backup_name'};
}

sub feature_validate
{
local ($d) = @_;
local $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
-r $cfile || return &text('feat_evalidate', "<tt>$cfile</tt>");
-d "$d->{'home'}/awstats" || return &text('feat_evalidatedir', "<tt>$d->{'home'}/awstats</tt>");
&foreign_require("cron", "cron-lib.pl");
local $job = &find_cron_job($d->{'dom'});
$job || return &text('feat_evalidatecron');
local $cgidir = &get_cgidir($d);
-r "$cgidir/awstats.pl" || return &text('feat_evalidateprog', "<tt>$cgidir/awstats.pl</tt>");
return undef;
}

# get_cgidir(&domain)
sub get_cgidir
{
local $cgidir = $config{'copyto'} ?
			"$_[0]->{'home'}/$config{'copyto'}" :
		defined(&virtual_server::cgi_bin_dir) ?
			&virtual_server::cgi_bin_dir($_[0]) :
			"$_[0]->{'home'}/cgi-bin";
return $cgidir;
}

sub get_htmldir
{
return defined(&virtual_server::public_html_dir) ?
	&virtual_server::public_html_dir($_[0]) :
	"$_[0]->{'home'}/public_html";
}

1;

