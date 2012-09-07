# Defines functions for this feature

require 'virtualmin-awstats-lib.pl';
$input_name = $module_name;
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
local ($edit) = @_;
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
local ($d, $field) = @_;
if ((!$field || $field eq 'dom') &&
    $d->{'dom'} ne &get_system_hostname()) {
	return -r "$config{'config_dir'}/awstats.$field->{'dom'}.conf" ?
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

# feature_import(domain-name, user-name, db-name)
# Returns 1 if this feature is already enabled for some domain being imported,
# or 0 if not
sub feature_import
{
local ($dname, $user, $db) = @_;
return -r "$config{'config_dir'}/awstats.$dname.conf" ? 1 : 0;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
&$virtual_server::first_print($text{'feat_setup'});

# Copy the template config file
local $model = &awstats_model_file();
if (!$model) {
	&$virtual_server::second_print($text{'save_emodel'});
	return 0;
	}
local $out = &backquote_logged("cp ".quotemeta($model)." ".quotemeta("$config{'config_dir'}/awstats.$_[0]->{'dom'}.conf")." 2>&1");
if ($?) {
	&$virtual_server::second_print(&text('save_ecopy', "<tt>$out</tt>"));
	return 0;
	}

# Copy awstats.pl and associated files into the domain
local $err = &setup_awstats_commands($_[0]);
if ($err) {
	&$virtual_server::second_print($err);
	return 0;
	}

# Create report directory
local $dir = "$_[0]->{'home'}/awstats";
&virtual_server::make_dir_as_domain_user($_[0], $dir, 0755);

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
&virtual_server::obtain_lock_cron($_[0]);
&foreign_require("cron", "cron-lib.pl");
&save_run_user($_[0]->{'dom'}, $_[0]->{'user'});
if (!$config{'nocron'}) {
	local $job = { 'user' => 'root',
		       'command' => "$cron_cmd $_[0]->{'dom'}",
		       'active' => 1,
		       'mins' => int(rand()*60),
		       'hours' => int(rand()*24),
		       'days' => '*',
		       'months' => '*',
		       'weekdays' => '*' };
	&cron::create_cron_job($job);
	}
&cron::create_wrapper($cron_cmd, $module_name, "awstats.pl");
&virtual_server::release_lock_cron($_[0]);

# Add script alias to make /awstats/awstats.pl work
&virtual_server::obtain_lock_web($_[0]);
local @ports = ( $_[0]->{'web_port'},
		 $_[0]->{'ssl'} ? ( $_[0]->{'web_sslport'} ) : ( ) );
local $cgidir = &get_cgidir($_[0]);
foreach my $port (@ports) {
	local ($virt, $vconf) = &virtual_server::get_apache_virtual(
					$_[0]->{'dom'}, $port);
	if ($virt) {
		local $conf = &apache::get_config();
		local @sa = &apache::find_directive("ScriptAlias", $vconf);
		local ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
		if (!$aw) {
			# Need to add
			push(@sa, "/awstats/ $cgidir/");
			&apache::save_directive("ScriptAlias", \@sa,
						$vconf, $conf);
			&flush_file_lines($virt->{'file'});
			&virtual_server::register_post_action(
			    defined(&main::restart_apache) ?
			     \&main::restart_apache :
			     \&virtual_server::restart_apache);
			}
		}
	}
&$virtual_server::second_print($virtual_server::text{'setup_done'});

# Setup password protection for awstats.pl
local $tmpl = &virtual_server::get_template($_[0]->{'template'});
if ($tmpl->{$module_name.'passwd'} ||
    $tmpl->{$module_name.'passwd'} eq '') {
	&$virtual_server::first_print($text{'feat_passwd'});
	local $added = 0;
	local $passwd_file = "$_[0]->{'home'}/.awstats-htpasswd";
	foreach my $p (@ports) {
		local $conf = &apache::get_config();
                local ($virt, $vconf) = &virtual_server::get_apache_virtual(
                        $_[0]->{'dom'}, $p);
                next if (!$virt);
		local $lref = &read_file_lines($virt->{'file'});
		splice(@$lref, $virt->{'eline'}, 0,
		       "<Files awstats.pl>",
		       "AuthName \"$_[0]->{'dom'} statistics\"",
		       "AuthType Basic",
		       "AuthUserFile $passwd_file",
		       "require valid-user",
		       "</Files>");
		$added++;
		&flush_file_lines($virt->{'file'});
		undef(@apache::get_config_cache);
		}
	if ($added) {
                &virtual_server::register_post_action(
			\&virtual_server::restart_apache);
		}
	&virtual_server::update_create_htpasswd($_[0], $passwd_file,
						$_[0]->{'user'});
        $_[0]->{'awstats_pass'} = $passwd_file;

	# Create bogus .htaccess file in ~/awstats , for protected directories
	# module to see
	&virtual_server::open_tempfile_as_domain_user($_[0], HTACCESS,
		">$dir/.htaccess");
	&print_tempfile(HTACCESS, "AuthName \"$_[0]->{'dom'} statistics\"\n");
	&print_tempfile(HTACCESS, "AuthType Basic\n");
	&print_tempfile(HTACCESS, "AuthUserFile $passwd_file\n");
	&print_tempfile(HTACCESS, "require valid-user\n");
	&virtual_server::close_tempfile_as_domain_user($_[0], HTACCESS);

	# Add to list of protected dirs
	&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
        &lock_file($htaccess_htpasswd::directories_file);
        local @dirs = &htaccess_htpasswd::list_directories();
        push(@dirs, [ $dir, $passwd_file, 0, 0, undef ]);
        &htaccess_htpasswd::save_directories(\@dirs);
        &unlock_file($htaccess_htpasswd::directories_file);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}

&virtual_server::release_lock_web($_[0]);
return 1;
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
local $changed;
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

	# Change domain name in Apache config
	local ($virt, $vconf, $conf) = &virtual_server::get_apache_virtual(
					$_[0]->{'dom'}, $_[0]->{'web_port'});
	local @files;
	@files = &apache::find_directive_struct("Files", $vconf) if ($virt);
	foreach my $file (@files) {
		local $an = &apache::find_directive(
			"AuthName", $file->{'members'});
		$an =~ s/$_[1]->{'dom'}/$_[0]->{'dom'}/g;
		&apache::save_directive("AuthName", [ $an ],
					$file->{'members'}, $conf);
		}
	if (@files) {
		&flush_file_lines($virt->{'file'});
                &virtual_server::register_post_action(
			\&virtual_server::restart_apache);
		}

	# Fix up domain in cron job
	&virtual_server::obtain_lock_cron($_[0]);
	&foreign_require("cron", "cron-lib.pl");
	local $job = &find_cron_job($_[1]->{'dom'});
	if ($job) {
		$job->{'command'} = "$cron_cmd $_[0]->{'dom'}";
		&cron::change_cron_job($job);
		}
	&virtual_server::release_lock_cron($_[0]);

	# Change run-as domain
	&rename_run_domain($_[0]->{'dom'}, $_[1]->{'dom'});

	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'user'} ne $_[1]->{'user'}) {
	# Username has changed .. update run-as user and possibly password
	&$virtual_server::first_print($text{'feat_modifyuser'});
	&save_run_user($_[0]->{'dom'}, $_[0]->{'user'});
	if ($_[0]->{'awstats_pass'}) {
		&virtual_server::update_create_htpasswd(
			$_[0], $_[0]->{'awstats_pass'}, $_[1]->{'user'});
		}
	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'home'} ne $_[1]->{'home'}) {
	# Home directory has changed .. update log and data dirs
	&$virtual_server::first_print($text{'feat_modifyhome'});
	local $cfile = &get_config_file($_[0]->{'dom'});
	&lock_file($cfile);
	local $conf = &get_config($_[0]->{'dom'});
	local $dir = "$_[0]->{'home'}/awstats";
	&save_directive($conf, $_[0]->{'dom'}, "DirData", $dir);
	&save_directive($conf, $_[0]->{'dom'}, "LogFile",
		&virtual_server::get_apache_log($_[0]->{'dom'},
					        $_[0]->{'web_port'}));
	&flush_file_lines($cfile);
	&unlock_file($cfile);

	# XXX also update password file too
	$changed++;
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
if ($_[0]->{'pass'} ne $_[1]->{'pass'}) {
	# Password has changed .. update web password
	if ($_[0]->{'awstats_pass'}) {
		&$virtual_server::first_print($text{'feat_modifypass'});
		&virtual_server::update_create_htpasswd(
			$_[0], $_[0]->{'awstats_pass'}, $_[0]->{'user'});
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	}
if ($changed) {
	# Fix links
	&setup_awstats_commands($_[0]);
	}
return 1;
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
# Delete config and cron job
&$virtual_server::first_print($text{'feat_delete'});
&virtual_server::obtain_lock_cron($_[0]);
&foreign_require("cron", "cron-lib.pl");
local $job = &find_cron_job($_[0]->{'dom'});
if ($job) {
	&cron::delete_cron_job($job);
	}
&virtual_server::release_lock_cron($_[0]);
&delete_config($_[0]->{'dom'});

# Delete awstats.pl from the cgi-bin directory
local $cgidir = &get_cgidir($_[0]);
&virtual_server::unlink_logged_as_domain_user($_[0], "$cgidir/awstats.pl");

# Delete links or directory copies
local $cgidir = &get_cgidir($_[0]);
foreach my $dir ("lib", "lang", "plugins") {
	&virtual_server::unlink_logged_as_domain_user($_[0], "$cgidir/$dir");
	}
local $htmldir = &get_htmldir($_[0]);
if (-l "$htmldir/icon") {
	&virtual_server::unlink_logged_as_domain_user($_[0], "$htmldir/icon");
	&virtual_server::unlink_logged_as_domain_user($_[0], "$htmldir/awstats-icon");
	&virtual_server::unlink_logged_as_domain_user($_[0], "$htmldir/awstatsicons");
	}

# Remove script alias for /awstats
&virtual_server::obtain_lock_web($_[0]);
local @ports = ( $_[0]->{'web_port'},
		 $_[0]->{'ssl'} ? ( $_[0]->{'web_sslport'} ) : ( ) );
foreach my $port (@ports) {
	local ($virt, $vconf) = &virtual_server::get_apache_virtual(
					$_[0]->{'dom'}, $port);
	if ($virt) {
		local $conf = &apache::get_config();
		local @sa = &apache::find_directive("ScriptAlias", $vconf);
		local ($aw) = grep { $_ =~ /^\/awstats/ } @sa;
		if ($aw) {
			# Need to remove
			@sa = grep { $_ ne $aw } @sa;
			&apache::save_directive("ScriptAlias", \@sa,
						$vconf, $conf);
			&flush_file_lines($virt->{'file'});
			&virtual_server::register_post_action(
			    defined(&main::restart_apache) ?
			     \&main::restart_apache :
			     \&virtual_server::restart_apache);
			}
		}
	}

# Remove runas entry
&delete_run_user($_[0]->{'dom'});
&$virtual_server::second_print($virtual_server::text{'setup_done'});

# Remove password protection for /awstats/awstats.pl
if ($_[0]->{'awstats_pass'}) {
	&$virtual_server::first_print($text{'feat_dpasswd'});
	local $deleted = 0;
	foreach my $p (@ports) {
		local $conf = &apache::get_config();
                local ($virt, $vconf) = &virtual_server::get_apache_virtual(
                        $_[0]->{'dom'}, $p);
		next if (!$virt);
		local ($loc) = grep { $_->{'words'}->[0] eq '/awstats' }
			    &apache::find_directive_struct("Location", $vconf);
		if (!$loc) {
			($loc) = grep { $_->{'words'}->[0] eq 'awstats.pl' }
			    &apache::find_directive_struct("Files", $vconf);
			}
		next if (!$loc);
		local $lref = &read_file_lines($virt->{'file'});
		splice(@$lref, $loc->{'line'},
		       $loc->{'eline'}-$loc->{'line'}+1);
		&flush_file_lines($virt->{'file'});
		undef(@apache::get_config_cache);
		$deleted++;
		}
	if ($deleted) {
                &virtual_server::register_post_action(
                    defined(&main::restart_apache) ? \&main::restart_apache
                                           : \&virtual_server::restart_apache);
		}
	delete($_[0]->{'awstats_pass'});

	# Remove from list of protected dirs
	local $dir = "$_[0]->{'home'}/awstats";
	&foreign_require("htaccess-htpasswd", "htaccess-lib.pl");
	&unlink_file("$dir/.htaccess");
	&lock_file($htaccess_htpasswd::directories_file);
	local @dirs = &htaccess_htpasswd::list_directories();
	@dirs = grep { $_->[0] ne $dir } @dirs;
	&htaccess_htpasswd::save_directories(\@dirs);
	&unlock_file($htaccess_htpasswd::directories_file);

	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}

&virtual_server::release_lock_web($_[0]);
return 1;
}

# feature_setup_alias(&domain, &alias)
# Called when an alias of this domain is created, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_setup_alias
{
local ($d, $alias) = @_;

# Add the alias to the .conf files
&$virtual_server::first_print(&text('feat_setupalias', $d->{'dom'}));
&symlink_logged(&get_config_file($d->{'dom'}),
		&get_config_file($alias->{'dom'}));
&symlink_logged(&get_config_file($d->{'dom'}),
		&get_config_file("www.".$alias->{'dom'}));

# Add to HostAliases
&lock_file(&get_config_file($d->{'dom'}));
local $conf = &get_config($d->{'dom'});
local $ha = &find_value("HostAliases", $conf);
$ha .= " REGEX[".quotemeta($alias->{'dom'})."\$]";
&save_directive($conf, $d->{'dom'}, "HostAliases", $ha);
&flush_file_lines(&get_config_file($d->{'dom'}));
&unlock_file(&get_config_file($d->{'dom'}));

# Link up existing data files
local $dirdata = &find_value("DirData", $conf);
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
local ($d, $alias) = @_;

# Remove the alias's .conf file
&$virtual_server::first_print(&text('feat_deletealias', $d->{'dom'}));
&unlink_logged(&get_config_file($alias->{'dom'}));
&unlink_logged(&get_config_file("www.".$alias->{'dom'}));

# Remove alias from HostAliases
&lock_file(&get_config_file($d->{'dom'}));
local $conf = &get_config($d->{'dom'});
local $ha = &find_value("HostAliases", $conf);
local $qd = quotemeta($alias->{'dom'});
$ha =~ s/\s*REGEX\[\Q$qd\E\$\]//;
&save_directive($conf, $d->{'dom'}, "HostAliases", $ha);
&flush_file_lines(&get_config_file($d->{'dom'}));
&unlock_file(&get_config_file($d->{'dom'}));

# Remove data symlinks
local $dirdata = &find_value("DirData", $conf);
&unlink_domain_alias_data($alias->{'dom'}, $dirdata);
&$virtual_server::second_print($virtual_server::text{'setup_done'});

return 1;
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
return ( # Link to either view a report, or edit settings
	 { 'mod' => $module_name,
           'desc' => $text{'links_view'},
           'page' => 'view.cgi?config='.&urlize($d->{'dom'}),
	   'cat' => 'logs',
         },
	 # Link to edit AWstats config for this domain
	 { 'mod' => $module_name,
           'desc' => $text{'links_config'},
           'page' => 'config.cgi?dom='.&urlize($d->{'dom'}),
	   'cat' => 'logs',
         },
       );
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
local $ok = 1;

# Restore the config file
&$virtual_server::first_print($text{'feat_restore'});
local $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
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
local ($d) = @_;

# Make sure config file exists
local $cfile = "$config{'config_dir'}/awstats.$d->{'dom'}.conf";
-r $cfile || return &text('feat_evalidate', "<tt>$cfile</tt>");

# Check for logs directory
-d "$d->{'home'}/awstats" || return &text('feat_evalidatedir', "<tt>$d->{'home'}/awstats</tt>");

# Check for cron job
if (!$config{'nocron'}) {
	&foreign_require("cron", "cron-lib.pl");
	local $job = &find_cron_job($d->{'dom'});
	$job || return &text('feat_evalidatecron');
	}

# Make sure awstats.pl exists, and is the same as the installed version, unless
# it is a link or wrapper
local $cgidir = &get_cgidir($d);
local $wrapper = "$cgidir/awstats.pl";
-r $wrapper || return &text('feat_evalidateprog', "<tt>$wrapper</tt>");
local @cst = stat($config{'awstats'});
local @dst = stat($wrapper);
if (@cst && $cst[7] != $dst[7] && !-l $wrapper) {
	open(WRAPPER, $wrapper);
	local $sh = <WRAPPER>;
	close(WRAPPER);
	if ($sh !~ /^#\!\/bin\/sh/) {
		return &text('feat_evalidatever', "<tt>$config{'awstats'}</tt>", "<tt>$cgidir/awstats.pl</tt>");
		}
	}

return undef;
}

# get_cgidir(&domain)
sub get_cgidir
{
local $cgidir = $config{'copyto'} ?
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
local ($tmpl) = @_;
local $v = $tmpl->{$module_name."passwd"};
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
local ($tmpl, $in) = @_;
$tmpl->{$module_name.'passwd'} = $in->{$input_name.'_passwd'};
}

1;

