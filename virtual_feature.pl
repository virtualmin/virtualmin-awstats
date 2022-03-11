# Defines functions for this feature
use strict;
use warnings;
our (%text, %config);
our $module_name;
our $cron_cmd;

require 'virtualmin-awstats-lib.pl';
my $input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;

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
my ($edit) = @_;
return $edit ? $text{'feat_label2'} : $text{'feat_label'};
}

sub feature_hlink
{
return "label";
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
my ($d) = @_;
return $text{'feat_edepweb'} if (!&virtual_server::domain_has_website($d));
return $text{'feat_edepunix'} if (!$d->{'unix'} && !$d->{'parent'});
return $text{'feat_edepdir'} if (!$d->{'dir'});
return undef;
}

# feature_clash(&domain, [field])
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
my ($d, $field) = @_;
if ((!$field || $field eq 'dom') &&
    $d->{'dom'} ne &get_system_hostname()) {
	return -r "$config{'config_dir'}/awstats.$d->{'dom'}.conf" ?
		$text{'feat_clash'} : undef;
	}
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
my ($parentdom, $aliasdom, $subdom) = @_;
return $aliasdom || $subdom ? 0 : 1;	# not for alias or sub domains
}

# feature_import(domain-name, user-name, db-name)
# Returns 1 if this feature is already enabled for some domain being imported,
# or 0 if not
sub feature_import
{
my ($dname, $user, $db) = @_;
return -r "$config{'config_dir'}/awstats.$dname.conf" ? 1 : 0;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
my ($d) = @_;
&$virtual_server::first_print($text{'feat_setup'});

# Copy the template config file
my $model = &awstats_model_file();
if (!$model) {
	&$virtual_server::second_print($text{'save_emodel'});
	return 0;
	}
my $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
my $ok = &copy_source_dest($model, $cfile);
if (!$ok) {
	&$virtual_server::second_print(&text('save_ecopy', "<tt>$!</tt>"));
	return 0;
	}

# Copy awstats.pl and associated files into the domain
my $err = &setup_awstats_commands($d);
if ($err) {
	&unlink_file($cfile);
	&$virtual_server::second_print($err);
	return 0;
	}

# Create report directory
my $dir = "$d->{'home'}/awstats";
&virtual_server::make_dir_as_domain_user($d, $dir, 0755);
my $outdir = &virtual_server::public_html_dir($d)."/awstats";

# Work out the log format
my $fmt;
if ($d->{'web'}) {
	# Get from Apache config
	my ($virt, $vconf) = &virtual_server::get_apache_virtual(
				$d->{'dom'}, $d->{'web_port'});
	my $clog = &apache::find_directive("CustomLog", $vconf);
	$fmt = $config{'format'} ? $config{'format'}
				 : $clog =~ /combined$/i ? 1 : 4;
	}
else {
	# Assume combined for other webservers
	$fmt = 1;
	}

# Update settings to match server
&lock_file(&get_config_file($d->{'dom'}));
my $conf = &get_config($d->{'dom'});
&save_directive($conf, $d->{'dom'}, "SiteDomain", "\"$d->{'dom'}\"");
my $qd = quotemeta($d->{'dom'});
my $aliases = &virtual_server::substitute_template($config{'aliases'}, $d);
&save_directive($conf, $d->{'dom'}, "HostAliases",
		"REGEX[$qd\$]".($aliases ? " $aliases" : ""));
&save_directive($conf, $d->{'dom'}, "LogFile",
	&virtual_server::get_website_log($d));
&save_directive($conf, $d->{'dom'}, "DirData", $dir);
&save_directive($conf, $d->{'dom'}, "LogFormat", $fmt);
&flush_file_lines();
&unlock_file(&get_config_file($d->{'dom'}));

# Symlink www.domain and IP file to domain
&symlink_logged(&get_config_file($d->{'dom'}),
		&get_config_file("www.".$d->{'dom'}));
if ($d->{'virt'}) {
	&symlink_logged(&get_config_file($d->{'dom'}),
			&get_config_file($d->{'ip'}));
	}

# Set up cron job
&virtual_server::obtain_lock_cron($d);
&foreign_require("cron", "cron-lib.pl");
&save_run_user($d->{'dom'}, $d->{'user'});
if (!$config{'nocron'}) {
	my $job = { 'user' => 'root',
		    'command' => "$cron_cmd ".
			  ($d->{'web'} ? "" : "--output $outdir ").$d->{'dom'},
		    'active' => 1,
		    'mins' => int(rand()*60),
		    'hours' => int(rand()*24),
		    'days' => '*',
		    'months' => '*',
		    'weekdays' => '*' };
	&cron::create_cron_job($job);
	}
&cron::create_wrapper($cron_cmd, $module_name, "awstats.pl");
&virtual_server::release_lock_cron($d);

if ($d->{'web'}) {
	# Add script alias to make /awstats/awstats.pl work (if running apache)
	&virtual_server::obtain_lock_web($d);
	my @ports = ( $d->{'web_port'},
			 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
	my $cgidir = &get_cgidir($d);
	foreach my $port (@ports) {
		my ($virt, $vconf) = &virtual_server::get_apache_virtual(
						$d->{'dom'}, $port);
		if ($virt) {
			my $conf = &apache::get_config();
			my @sa = &apache::find_directive(
				"ScriptAlias", $vconf);
			my ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
			if (!$aw) {
				# Need to add
				push(@sa, "/awstats/ $cgidir/");
				&apache::save_directive("ScriptAlias", \@sa,
							$vconf, $conf);
				&flush_file_lines($virt->{'file'});
				&virtual_server::register_post_action(
				     \&virtual_server::restart_apache);
				}
			}
		}
	&virtual_server::release_lock_web($d);
	}
else {
	# Create output dir under the web root (for nginx)
	&virtual_server::make_dir_as_domain_user($d, $outdir);
	}
&$virtual_server::second_print($virtual_server::text{'setup_done'});

# Setup password protection for awstats.pl
my $tmpl = &virtual_server::get_template($d->{'template'});
my $p = $tmpl->{$module_name.'passwd'} || '';
if ($d->{'web'} && $p ne '0') {
	&$virtual_server::first_print($text{'feat_passwd'});
	&virtual_server::obtain_lock_web($d);
	my $added = 0;
	my $passwd_file = "$d->{'home'}/.awstats-htpasswd";
	my @ports = ( $d->{'web_port'},
			 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
	foreach my $p (@ports) {
		my $conf = &apache::get_config();
                my ($virt, $vconf) = &virtual_server::get_apache_virtual(
                        $d->{'dom'}, $p);
                next if (!$virt);
		my $lref = &read_file_lines($virt->{'file'});
		splice(@$lref, $virt->{'eline'}, 0,
		       "    <Files awstats.pl>",
		       "    AuthName \"$d->{'dom'} statistics\"",
		       "    AuthType Basic",
		       "    AuthUserFile $passwd_file",
		       "    require valid-user",
		       "    </Files>");
		$added++;
		&flush_file_lines($virt->{'file'});
		undef(@apache::get_config_cache);
		}
	if ($added) {
                &virtual_server::register_post_action(
			\&virtual_server::restart_apache);
		}
	&virtual_server::update_create_htpasswd($d, $passwd_file,
						$d->{'user'});
        $d->{'awstats_pass'} = $passwd_file;

	# Create bogus .htaccess file in ~/awstats , for protected directories
	# module to see
	no strict "subs"; # XXX Lexical?
	&virtual_server::open_tempfile_as_domain_user($d, HTACCESS,
		">$dir/.htaccess");
	&print_tempfile(HTACCESS, "AuthName \"$d->{'dom'} statistics\"\n");
	&print_tempfile(HTACCESS, "AuthType Basic\n");
	&print_tempfile(HTACCESS, "AuthUserFile $passwd_file\n");
	&print_tempfile(HTACCESS, "require valid-user\n");
	&virtual_server::close_tempfile_as_domain_user($d, HTACCESS);
	use strict "subs";

	# Add to list of protected dirs
	&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
        &lock_file($htaccess_htpasswd::directories_file);
        my @dirs = &htaccess_htpasswd::list_directories();
        push(@dirs, [ $dir, $passwd_file, 0, 0, undef ]);
        &htaccess_htpasswd::save_directories(\@dirs);
        &unlock_file($htaccess_htpasswd::directories_file);

	&virtual_server::release_lock_web($d);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}

return 1;
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
my ($d, $oldd) = @_;
my $changed;
if ($d->{'dom'} ne $oldd->{'dom'}) {
	# Domain has been re-named .. rename awstats config
	&$virtual_server::first_print($text{'feat_modify'});
	my $oldfile = &get_config_file($oldd->{'dom'});
	my $newfile = &get_config_file($d->{'dom'});
	&rename_logged($oldfile, $newfile);
	&unlink_logged(&get_config_file("www.".$oldd->{'dom'}));
	&symlink_logged(&get_config_file($d->{'dom'}),
			&get_config_file("www.".$d->{'dom'}));
	if ($d->{'virt'}) {
		&unlink_logged(&get_config_file($oldd->{'ip'}));
		&symlink_logged(&get_config_file($d->{'dom'}),
				&get_config_file($d->{'ip'}));
		}

	# Update hostname in file
	&lock_file($newfile);
	my $conf = &get_config($d->{'dom'});
	foreach my $dir ("SiteDomain", "HostAliases") {
		my $v = &find_value($dir, $conf);
		$v =~ s/$oldd->{'dom'}/$d->{'dom'}/g;
		&save_directive($conf, $d->{'dom'}, $dir, $v);
		}
	&flush_file_lines();
	&unlock_file($newfile);

	# Change domain name in Apache config
	if ($d->{'web'}) {
		my ($virt, $vconf, $conf) =
			&virtual_server::get_apache_virtual(
			$d->{'dom'}, $d->{'web_port'});
		my @files;
		@files = &apache::find_directive_struct("Files", $vconf) if ($virt);
		foreach my $file (@files) {
			my $an = &apache::find_directive(
				"AuthName", $file->{'members'});
			$an =~ s/$oldd->{'dom'}/$d->{'dom'}/g;
			&apache::save_directive("AuthName", [ $an ],
						$file->{'members'}, $conf);
			}
		if (@files) {
			&flush_file_lines($virt->{'file'});
			&virtual_server::register_post_action(
				\&virtual_server::restart_apache);
			}
		}

	# Fix up domain in cron job
	&virtual_server::obtain_lock_cron($d);
	&foreign_require("cron");
	my $job = &find_cron_job($oldd->{'dom'});
	if ($job) {
		$job->{'command'} =~ s/\Q$oldd->{'dom'}\E$/$d->{'dom'}/;
		&cron::change_cron_job($job);
		}
	&virtual_server::release_lock_cron($d);

	# Change run-as domain
	&rename_run_domain($d->{'dom'}, $oldd->{'dom'});

	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($d->{'user'} ne $oldd->{'user'}) {
	# Username has changed .. update run-as user and possibly password
	&$virtual_server::first_print($text{'feat_modifyuser'});
	&save_run_user($d->{'dom'}, $d->{'user'});
	if ($d->{'awstats_pass'}) {
		&virtual_server::update_create_htpasswd(
			$d, $d->{'awstats_pass'}, $oldd->{'user'});
		}
	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($d->{'home'} ne $oldd->{'home'}) {
	# Home directory has changed .. update log and data dirs
	&$virtual_server::first_print($text{'feat_modifyhome'});
	my $cfile = &get_config_file($d->{'dom'});
	&lock_file($cfile);
	my $conf = &get_config($d->{'dom'});
	my $dir = "$d->{'home'}/awstats";
	&save_directive($conf, $d->{'dom'}, "DirData", $dir);
	&save_directive($conf, $d->{'dom'}, "LogFile",
		&virtual_server::get_website_log($d));
	&flush_file_lines($cfile);
	&unlock_file($cfile);

	# XXX also update password file too
	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if (defined($d->{'pass'}) &&
    $d->{'pass'} ne $oldd->{'pass'} && $d->{'web'}) {
	# Password has changed .. update web password
	if ($d->{'awstats_pass'}) {
		&$virtual_server::first_print($text{'feat_modifypass'});
		&virtual_server::update_create_htpasswd(
			$d, $d->{'awstats_pass'}, $d->{'user'});
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	}
my $alog = &virtual_server::get_website_log($d);
my $oldalog = &virtual_server::get_old_website_log($alog, $d, $oldd);
if ($alog ne $oldalog) {
	# Log file has been renamed - update AWStats config
	&$virtual_server::first_print($text{'feat_modifylog'});
	my $cfile = &get_config_file($d->{'dom'});
	&lock_file($cfile);
	my $conf = &get_config($d->{'dom'});
	&save_directive($conf, $d->{'dom'}, "LogFile", $alog);
	&flush_file_lines($cfile);
	&unlock_file($cfile);
	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($changed) {
	# Fix links
	&setup_awstats_commands($d);
	}
return 1;
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
my ($d) = @_;

# Delete config and cron job
&$virtual_server::first_print($text{'feat_delete'});
&virtual_server::obtain_lock_cron($d);
&foreign_require("cron", "cron-lib.pl");
my $job = &find_cron_job($d->{'dom'});
if ($job) {
	&cron::delete_cron_job($job);
	}
&virtual_server::release_lock_cron($d);
&delete_config($d->{'dom'});
if ($d->{'virt'}) {
	&delete_config($d->{'ip'});
	}

# Delete awstats.pl from the cgi-bin directory
my $cgidir = &get_cgidir($d);
&virtual_server::unlink_logged_as_domain_user($d, "$cgidir/awstats.pl");

# Delete links or directory copies
foreach my $dir ("lib", "lang", "plugins") {
	&virtual_server::unlink_logged_as_domain_user($d, "$cgidir/$dir");
	}
my $htmldir = &get_htmldir($d);
foreach my $dir ("icon", "awstats-icon", "awstatsicons") {
	if (-l "$htmldir/$dir") {
		&virtual_server::unlink_logged_as_domain_user($d, "$htmldir/$dir");
		}
	elsif (-d "$htmldir/$dir") {
		# Might be a copy of the icon dir
		my @srcs = glob("$config{'icons'}/*");
		my @dsts = glob("$htmldir/$dir/*");
		if (scalar(@srcs) == scalar(@dsts)) {
			&virtual_server::unlink_logged_as_domain_user($d,"$htmldir/$dir");
			}
		}
	}

# Remove script alias for /awstats
if ($d->{'web'}) {
	&virtual_server::obtain_lock_web($d);
	my @ports = ( $d->{'web_port'},
			 $d->{'ssl'} ? ( $d->{'web_sslport'} ) : ( ) );
	foreach my $port (@ports) {
		my ($virt, $vconf) = &virtual_server::get_apache_virtual(
						$d->{'dom'}, $port);
		if ($virt) {
			my $conf = &apache::get_config();
			my @sa = &apache::find_directive(
				"ScriptAlias", $vconf);
			my ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
			if ($aw) {
				# Need to remove
				@sa = grep { $_ ne $aw } @sa;
				&apache::save_directive("ScriptAlias", \@sa,
							$vconf, $conf);
				&flush_file_lines($virt->{'file'});
				&virtual_server::register_post_action(
				     \&virtual_server::restart_apache);
				}
			}
		}

	# Remove runas entry
	&delete_run_user($d->{'dom'});
	&$virtual_server::second_print($virtual_server::text{'setup_done'});

	# Remove password protection for /awstats/awstats.pl
	if ($d->{'awstats_pass'}) {
		&$virtual_server::first_print($text{'feat_dpasswd'});
		my $deleted = 0;
		foreach my $p (@ports) {
			my $conf = &apache::get_config();
			my ($virt, $vconf) = &virtual_server::get_apache_virtual(
				$d->{'dom'}, $p);
			next if (!$virt);
			my ($loc) = grep { $_->{'words'}->[0] eq '/awstats' }
				    &apache::find_directive_struct("Location", $vconf);
			if (!$loc) {
				($loc) = grep { $_->{'words'}->[0] eq 'awstats.pl' }
				    &apache::find_directive_struct("Files", $vconf);
				}
			next if (!$loc);
			my $lref = &read_file_lines($virt->{'file'});
			splice(@$lref, $loc->{'line'},
			       $loc->{'eline'}-$loc->{'line'}+1);
			&flush_file_lines($virt->{'file'});
			undef(@apache::get_config_cache);
			$deleted++;
			}
		if ($deleted) {
			&virtual_server::register_post_action(
				\&virtual_server::restart_apache);
			}
		delete($d->{'awstats_pass'});

		# Remove from list of protected dirs
		my $dir = "$d->{'home'}/awstats";
		&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
		&unlink_file("$dir/.htaccess");
		&lock_file($htaccess_htpasswd::directories_file);
		my @dirs = &htaccess_htpasswd::list_directories();
		@dirs = grep { $_->[0] ne $dir } @dirs;
		&htaccess_htpasswd::save_directories(\@dirs);
		&unlock_file($htaccess_htpasswd::directories_file);
		}

	&virtual_server::release_lock_web($d);
	}
&$virtual_server::second_print(
	$virtual_server::text{'setup_done'});
return 1;
}

# feature_setup_alias(&domain, &alias)
# Called when an alias of this domain is created, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_setup_alias
{
my ($d, $alias) = @_;

# Add the alias to the .conf files
&$virtual_server::first_print(&text('feat_setupalias', $d->{'dom'}));
&symlink_logged(&get_config_file($d->{'dom'}),
		&get_config_file($alias->{'dom'}));
&symlink_logged(&get_config_file($d->{'dom'}),
		&get_config_file("www.".$alias->{'dom'}));

# Add to HostAliases
&lock_file(&get_config_file($d->{'dom'}));
my $conf = &get_config($d->{'dom'});
my $ha = &find_value("HostAliases", $conf);
$ha .= " REGEX[".quotemeta($alias->{'dom'})."\$]";
&save_directive($conf, $d->{'dom'}, "HostAliases", $ha);
&flush_file_lines(&get_config_file($d->{'dom'}));
&unlock_file(&get_config_file($d->{'dom'}));

# Link up existing data files
my $dirdata = &find_value("DirData", $conf);
&link_domain_alias_data($d->{'dom'}, $dirdata, $d->{'user'});
&$virtual_server::second_print($virtual_server::text{'setup_done'});

return 1;
}

# feature_delete_alias(&domain, &alias)
# Called when an alias of this domain is deleted, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_delete_alias
{
my ($d, $alias) = @_;

# Remove the alias's .conf file
&$virtual_server::first_print(&text('feat_deletealias', $d->{'dom'}));
&unlink_logged(&get_config_file($alias->{'dom'}));
&unlink_logged(&get_config_file("www.".$alias->{'dom'}));

# Remove alias from HostAliases
&lock_file(&get_config_file($d->{'dom'}));
my $conf = &get_config($d->{'dom'});
my $ha = &find_value("HostAliases", $conf);
my $qd = quotemeta($alias->{'dom'});
$ha =~ s/\s*REGEX\[\Q$qd\E\$\]//;
&save_directive($conf, $d->{'dom'}, "HostAliases", $ha);
&flush_file_lines(&get_config_file($d->{'dom'}));
&unlock_file(&get_config_file($d->{'dom'}));

# Remove data symlinks
my $dirdata = &find_value("DirData", $conf);
&unlink_domain_alias_data($alias->{'dom'}, $dirdata);
&$virtual_server::second_print($virtual_server::text{'setup_done'});

return 1;
}

# feature_webmin(&domain, &other)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
my @doms = map { $_->{'dom'} } grep { $_->{$module_name} } @{$_[1]};
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

# feature_modules()
# Returns a list of the modules that domain owners with this feature may be
# granted access to. Used in server templates.
sub feature_modules
{
return ( [ $module_name, $text{'feat_module'} ] );
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
my ($d) = @_;
return ( # Link to either view a report, or edit settings
	 { 'mod' => $module_name,
           'desc' => $text{'links_view'},
           'page' => 'view.cgi?config='.&urlize($d->{'dom'}),
	   'cat' => 'logs',
         },
	 # Link to edit AWStats config for this domain
	 { 'mod' => $module_name,
           'desc' => $text{'links_config'},
           'page' => 'config.cgi?linked=1&dom='.&urlize($d->{'dom'}),
	   'cat' => 'services',
         },
       );
}

# feature_backup(&domain, file, &opts, &all-opts)
# Copy the awstats config file for the domain
sub feature_backup
{
my ($d, $file, $opts) = @_;
&$virtual_server::first_print($text{'feat_backup'});
my $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
if (-r $cfile) {
	&virtual_server::copy_write_as_domain_user($d, $cfile, $file);
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
my ($d, $file, $opts) = @_;
my $ok = 1;

# Restore the config file
&$virtual_server::first_print($text{'feat_restore'});
my $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
&lock_file($cfile);
if (&copy_source_dest($file, $cfile)) {
	&unlock_file($cfile);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
else {
	&$virtual_server::second_print($text{'feat_nocopy'});
	$ok = 0;
	}

# Re-setup awstats.pl, lib, plugins and icons, as the old paths in the backup
# probably don't match this system
&setup_awstats_commands($d);

return $ok;
}

sub feature_backup_name
{
return $text{'feat_backup_name'};
}

sub feature_validate
{
my ($d) = @_;

# Make sure config file exists
my $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
-r $cfile || return &text('feat_evalidate', "<tt>$cfile</tt>");

# Check for logs directory
-d "$d->{'home'}/awstats" || return &text('feat_evalidatedir', "<tt>$d->{'home'}/awstats</tt>");

# Check for cron job
if (!$config{'nocron'}) {
	&foreign_require("cron", "cron-lib.pl");
	my $job = &find_cron_job($d->{'dom'});
	$job || return &text('feat_evalidatecron');
	}

# Make sure awstats.pl exists, and is the same as the installed version, unless
# it is a link or wrapper
my $cgidir = &get_cgidir($d);
my $wrapper = "$cgidir/awstats.pl";
-r $wrapper || return &text('feat_evalidateprog', "<tt>$wrapper</tt>");
my @cst = stat($config{'awstats'});
my @dst = stat($wrapper);
if (@cst && $cst[7] != $dst[7] && !-l $wrapper) {
	open(my $WRAPPER, "<", $wrapper);
	my $sh = <$WRAPPER>;
	close($WRAPPER);
	if ($sh !~ /^#\!\/bin\/sh/) {
		return &text('feat_evalidatever', "<tt>$config{'awstats'}</tt>", "<tt>$cgidir/awstats.pl</tt>");
		}
	}

return undef;
}

# get_cgidir(&domain)
sub get_cgidir
{
my $cgidir = $config{'copyto'} ?
			"$_[0]->{'home'}/$config{'copyto'}" :
			&virtual_server::cgi_bin_dir($_[0]);
return $cgidir;
}

sub get_htmldir
{
return &virtual_server::public_html_dir($_[0]);
}

# template_input(&template)
# Returns HTML for editing per-template options for this plugin
sub template_input
{
my ($tmpl) = @_;
my $v = $tmpl->{$module_name."passwd"};
$v = 1 if (!defined($v) && $tmpl->{'default'});
return &ui_table_row($text{'tmpl_passwd'},
	&ui_radio($input_name."_passwd", $v,
		  [ $tmpl->{'default'} ? ( ) : ( [ '', $text{'default'} ] ),
		    [ 1, $text{'yes'} ],
		    [ 0, $text{'no'} ] ]));
}

# template_parse(&template, &in)
# Updates the given template object by parsing the inputs generated by
# template_input. All template fields must start with the module name.
sub template_parse
{
my ($tmpl, $in) = @_;
$tmpl->{$module_name.'passwd'} = $in->{$input_name.'_passwd'};
}

1;

