# Functions for configuring AWStats
use strict;
use warnings;
our (%access, %config);
our $module_config_directory;
our %get_config_cache;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
%access = &get_module_acl();

our $cron_cmd = "$module_config_directory/awstats.pl";
our $run_as_file = "$module_config_directory/runas";

# list_configs()
# Returns a list of domains for which AWStats is configured
sub list_configs
{
my @rv;
my $dir = &translate_filename($config{'config_dir'});
opendir(DIR, $dir);
foreach my $f (readdir(DIR)) {
	if ($f =~ /^awstats\.(\S+)\.conf$/ && !-l "$dir/$f") {
		push(@rv, $1);
		}
	}
closedir(DIR);
return @rv;
}

# get_config(domain)
# Parses the AWStats configuration for some virtual server into a array ref of
# values.
sub get_config
{
my ($dom) = @_;
if (!defined($get_config_cache{$dom})) {
	my @rv;
	my $lnum = 0;
	my $cfile = &get_config_file($dom);
	no strict "subs"; # XXX Lexical?
	&open_readfile(FILE, $cfile) || &error("Failed to open $cfile : $!");
	while(<FILE>) {
		s/\r|\n//g;
		s/^\s*#.*$//;
		if (/^([^=]+)\s*=\s*"(.*)"/ ||
		    /^([^=]+)\s*=\s*'(.*)'/ ||
		    /^([^=]+)\s*=\s*(\S*)/) {
			# Found a directive
			push(@rv, { 'name' => $1,
				    'value' => $2,
				    'line' => $lnum });
			}
		$lnum++;
		}
	close(FILE);
	use strict "subs";
	$get_config_cache{$dom} = \@rv;
	}
return $get_config_cache{$dom};
}

# get_config_file(domain)
# Returns the AWStats config file for some domain
sub get_config_file
{
return "$config{'config_dir'}/awstats.$_[0].conf";
}

# find_value(name, &conf)
# Returns the value of some AWStats directive
sub find_value
{
my ($name, $conf) = @_;
my ($dir) = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return $dir ? $dir->{'value'} : undef;
}

# find_values(name, &conf)
# Returns all values for some directive
sub find_values
{
my ($name, $conf) = @_;
my @dirs = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return map { $_->{'value'} } @dirs;
}

# save_directive(&config, domain, name, value)
# Updates some value in the AWStats config
sub save_directive
{
my ($conf, $dom, $name, $value) = @_;
my $file = &get_config_file($dom);
my $lref = &read_file_lines($file);
my ($dir) = grep { lc($_->{'name'}) eq lc($name) } @$conf;
my $line;
if (defined($value)) {
	$line = $value =~ /\s/ && $value =~ /"/ ?
		"$name='$value'" :
		$value =~ /\s/ ? "$name=\"$value\"" : "$name=$value";
	}
if ($dir && defined($value)) {
	# Update file
	$lref->[$dir->{'line'}] = $line;
	$dir->{'value'} = $value;
	}
elsif ($dir && !defined($value)) {
	# Delete from file
	splice(@$lref, $dir->{'line'}, 1);
	foreach my $c (@$conf) {
		if ($c->{'line'} > $dir->{'line'}) { $c->{'line'}--; }
		}
	@$conf = grep { $_ ne $dir } @$conf;
	}
elsif (!$dir && defined($value)) {
	# Add to file
	push(@$conf, { 'name' => $name,
		       'value' => $value,
		       'line' => scalar(@$lref) });
	push(@$lref, $line);
	}
}

# save_directives(&config, domain, name, &values)
# Updates all values for some named directive in the config file
sub save_directives
{
my ($conf, $dom, $name, $values) = @_;
my @values = @$values;
my $file = &get_config_file($dom);
my $lref = &read_file_lines($file);

foreach my $l (@$lref) {
	if ($l =~ /^(#*)\s*\Q$name\E\s*=\s*(.*)/i) {
		# Found an existing line, perhaps commented
		my ($cmt, $oldv) = ($1, $2);
		$oldv = $oldv =~ /^"(.*)"/ ? $1 :
			$oldv =~ /^'(.*)'/ ? $1 : $oldv;
		my $idx = &indexof($oldv, @values);
		if ($idx >= 0 && !$cmt) {
			# Already enabled, so do nothing
			}
		elsif ($idx >= 0 && $cmt) {
			# Commented out .. fix up
			$l =~ s/^#+\s*//;
			}
		elsif ($idx < 0 && !$cmt) {
			# No longer needed .. comment out
			$l = "#$l";
			}
		if ($idx >= 0) {
			splice(@values, $idx, 1);
			}
		}
	}

# Append any values not in the file at all yet
foreach my $v (@values) {
	my $line = $v =~ /\s/ && $v =~ /"/ ?
		"$name='$v'" :
		$v =~ /\s/ ? "$name=\"$v\"" : "$name=$v";
	push(@$lref, $line);
	}
}

# delete_config(domain)
# Deletes the config for one domain
sub delete_config
{
my ($dom) = @_;
&unlink_logged(&get_config_file("www.".$dom));
&unlink_logged(&get_config_file($dom));
}

# can_domain(domain)
# Returns 1 if the current user can manage some AWStats domain
sub can_domain
{
return 1 if ($access{'domains'} eq '*');
my %can = map { $_, 1 } split(/\s+/, $access{'domains'});
return $can{$_[0]};
}

# awstats_model_file()
# Returns the full path to the template AWStats config file, or undef if none
sub awstats_model_file
{
foreach my $f ("awstats.model.conf", "awstats.conf") {
	my $p = "$config{'config_dir'}/$f";
	return $p if (-r $p);
	}
return undef;
}

# Returns an error message if awstats is missing
sub check_awstats
{
return &text('check_ecmd', "<tt>$config{'awstats'}</tt>")
	if (!&has_command($config{'awstats'}));
return &text('check_edir', "<tt>$config{'config_dir'}</tt>")
	if (!-d $config{'config_dir'});
return &text('check_econs', "<tt>$config{'icons'}</tt>")
	if (!-d $config{'icons'});
return &text('check_emodel',
	     "<tt>$config{'config_dir'}/awstats.model.conf</tt>")
	if (!&awstats_model_file());
return undef;
}

# find_cron_job(domain)
# Finds the Cron job that generates stats for some domain
sub find_cron_job
{
my ($dom) = @_;
my @jobs = &cron::list_cron_jobs();
my ($job) = grep { $_->{'user'} eq 'root' &&
		   $_->{'command'} =~ /^\Q$cron_cmd\E\s+(--output\s+\S+\s+)?\Q$dom\E$/ } @jobs;
return $job;
}

# get_run_user(domain)
# Returns the user to run awstats as for some domain, from the module's
# internal list
sub get_run_user
{
my ($dname) = @_;
$dname ||= "";
my %runas;
&read_file_cached($run_as_file, \%runas);
return $runas{$dname} || "root";
}

# save_run_user(domain, user)
sub save_run_user
{
my %runas;
&read_file_cached($run_as_file, \%runas);
$runas{$_[0]} = $_[1];
&write_file($run_as_file, \%runas);
}

# rename_run_domain(domain, olddomain)
sub rename_run_domain
{
my %runas;
&read_file_cached($run_as_file, \%runas);
if ($runas{$_[1]}) {
	$runas{$_[0]} = $runas{$_[1]};
	delete($runas{$_[1]});
	}
&write_file($run_as_file, \%runas);
}

# delete_run_user(domain)
sub delete_run_user
{
my %runas;
&read_file_cached($run_as_file, \%runas);
delete($runas{$_[0]});
&write_file($run_as_file, \%runas);
}

# generate_report(domain, handle, html-escape?)
# Updates the AWStats report for a particular domain, from all of its
# log files (or at least those that have changed since the last run)
sub generate_report
{
my ($dom, $fh, $esc) = @_;
my $user = &get_run_user($dom);
my $cmd = "$config{'awstats'} -config=$dom -update";
$ENV{'GATEWAY_INTERFACE'} = undef;

# Find all the log files
my $conf = &get_config($dom);
my $baselog = &find_value("LogFile", $conf);
my @all = $baselog =~ /\|\s*$/ ? ( undef ) : &all_log_files($baselog);

# Find last modified time for each log file
my ($all, %mtime);
foreach my $all (@all) {
	my @st = stat($all);
	$mtime{$all} = $st[9];
	}

# Do each log file that we haven't already done
my $anyok = 0;
foreach my $a (sort { $mtime{$a} <=> $mtime{$b} } @all) {
	my $fullcmd = $cmd;
	if ($a =~ /\.gz$/i) {
		$fullcmd .= " -logfile=".quotemeta("gunzip -c $a |");
		}
	elsif ($a =~ /\.Z$/i) {
		$fullcmd .= " -logfile=".quotemeta("uncompress -c $a |");
		}
	elsif ($a =~ /\.bz2$/i) {
		$fullcmd .= " -logfile=".quotemeta("bunzip -c $a |");
		}
	elsif ($a) {
		$fullcmd .= " -logfile=".quotemeta($a);
		}
	if ($user ne "root") {
		$fullcmd = &command_as_user($user, 0, $fullcmd);
		}
	$fullcmd .= " 2>&1";
	no strict "subs";
	&open_execute_command(OUT, $fullcmd, 1, 0);
	while(<OUT>) {
		if ($esc) {
			print $fh &html_escape($_);
			}
		else {
			print $fh $_;
			}
		}
	close(OUT);
	use strict "subs";
	$anyok = 1 if (!$?);
	&additional_log("exec", undef, $fullcmd);
	}

# Link all awstatsXXXX.domain.txt files to awstatsXXXX.www.domain.txt , so
# that the URL www.domain.com/awstats/awstats.pl works
my $dirdata = &find_value("DirData", $conf);
&link_domain_alias_data($dom, $dirdata, $user);

return $anyok;
}

# generate_html(domain, dir)
# Use the data files for some domain to generate a static HTML report
sub generate_html
{
my ($dom, $dir) = @_;
my $user = &get_run_user($dom);
my $cmd = "$config{'awstats'} -config=$dom -output -staticlinks >$dir/index.html";
$ENV{'GATEWAY_INTERFACE'} = undef;
if ($user ne "root") {
	$cmd = &command_as_user($user, 0, $cmd);
	}
&execute_command($cmd);
}

# clear_data_directory(dir)
# Remove all .txt files in some data directory
sub clear_data_directory
{
my ($dom, $dir) = @_;
my $user = &get_run_user($dom);
my $count = 0;
foreach my $f (glob("$dir/*.txt")) {
	my $cmd = &command_as_user($user, 0, "rm -f ".quotemeta($f));
	&system_logged("$cmd >/dev/null 2>&1");
	$count++;
	}
return $count;
}

# link_domain_alias_data(domain, data-dir, user)
# Create symlinks from all awstatsXXXX.domain.txt files to
# awstatsXXXX.www.domain.txt , so that the URL
# www.domain.com/awstats/awstats.pl works. If the domain is used by Virtualmin,
# alias link up any aliases of this domain
sub link_domain_alias_data
{
my ($dom, $dirdata, $user) = @_;
my @otherdoms = ( "www.".$dom );
my $d;
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	$d = &virtual_server::get_domain_by("dom", $dom);
	if ($d) {
		foreach my $ad (&virtual_server::get_domain_by(
				"alias", $d->{'id'})) {
			push(@otherdoms, $ad->{'dom'}, "www.".$ad->{'dom'});
			}
		}
	}
if (opendir(DIRDATA, $dirdata)) {
	foreach my $f (readdir(DIRDATA)) {
		$f =~ /^awstats(\d+)\.\Q$dom\E\.txt$/ || next;
		foreach my $other (@otherdoms) {
			my $wwwf = "awstats".$1.".".$other.".txt";
			next if (-r "$dirdata/$wwwf");
			if ($d) {
				&virtual_server::symlink_file_as_domain_user(
					$d, $f, "$dirdata/$wwwf");
				}
			else {
				&symlink_logged($f, "$dirdata/$wwwf");
				&set_ownership_permissions($user, undef, undef,
							   "$dirdata/$wwwf");
				}
			}
		}
	closedir(DIRDATA);
	}
}

# unlink_domain_alias_data(domain-name, directory)
# Remove any symbolic links for AWStats data files for some domain
sub unlink_domain_alias_data
{
my ($aliasdom, $dirdata) = @_;
opendir(DIRDATA, $dirdata);
foreach my $f (readdir(DIRDATA)) {
	if ($f =~ /^awstats(\d+)\.(www\.)?\Q$aliasdom\E\.txt$/) {
		&unlink_logged("$dirdata/$f");
		}
	}
closedir(DIRDATA);
}

# all_log_files(file)
# Given a base log file name, returns a list of all log files in the same
# directory that start with the same name
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
my $dir = $1;
my $base = $2;
my ($f, @rv);
opendir(DIR, $dir);
foreach my $f (readdir(DIR)) {
	if ($f =~ /^\Q$base\E/ && -f "$dir/$f") {
		push(@rv, "$dir/$f");
		}
	}
closedir(DIR);
return @rv;
}

# setup_awstats_commands(&domain)
# Copy awstats.pl and associated lib and data files into a domain's directory
sub setup_awstats_commands
{
my ($d) = @_;

# Create an awstats.pl wrapper in the cgi-bin directory. Linking doesn't work,
# due to suexec restrictions
my $cgidir = &get_cgidir($d);
my $wrapper = "$cgidir/awstats.pl";
&lock_file($wrapper);
no strict "subs"; # XXX Lexical?
&virtual_server::open_tempfile_as_domain_user($d, WRAPPER, ">$wrapper");
&print_tempfile(WRAPPER, "#!/bin/sh\n");
&print_tempfile(WRAPPER, "exec $config{'awstats'}\n");
&virtual_server::close_tempfile_as_domain_user($d, WRAPPER);
use strict "subs";
&virtual_server::set_permissions_as_domain_user($d, 0755, $wrapper);
&unlock_file($wrapper);

# Link other directories from source dir
foreach my $dir ("lib", "lang", "plugins") {
	my $src;
	if ($config{$dir} && -d $config{$dir}) {
		# Specific directory is in config .. use it
		$src = $config{$dir};
		$src .= "/$dir" if ($src !~ /\/\Q$dir\E$/);
		}
	if (!$src || !-d $src) {
		# Use same directory as awstats.pl
		$config{'awstats'} =~ /^(.*)\//;
		$src = $1;
		$src .= "/$dir" if ($src !~ /\/\Q$dir\E$/);
		}
	if ($src && -d $src) {
		&virtual_server::unlink_logged_as_domain_user(
			$d, "$cgidir/$dir");
		&virtual_server::symlink_logged_as_domain_user(
			$d, $src, "$cgidir/$dir");
		}
	}

# Copy over icons directory
my $htmldir = &get_htmldir($d);
my @dirs = ( "icon", "awstats-icon", "awstatsicons" );
if (!-d "$htmldir/$dirs[0]") {
	&virtual_server::unlink_logged_as_domain_user($d,
		map { "$htmldir/$_" } @dirs);
	no warnings "once"; # XXX No idea how to predeclare this?
	if ($virtual_server::config{'allow_symlinks'} &&
	    $virtual_server::config{'allow_symlinks'} eq '1') {
		# Can still use links
		foreach my $dir (@dirs) {
			&virtual_server::symlink_logged_as_domain_user(
				$d, $config{'icons'}, "$htmldir/$dir");
			}
		}
	else {
		# Need to copy and chown
		&copy_source_dest($config{'icons'}, "$htmldir/$dirs[0]");
		&system_logged("chown -R $d->{'uid'}:$d->{'gid'} ".
			       quotemeta("$htmldir/$dirs[0]"));
		foreach my $dir (@dirs[1..$#dirs]) {
			&virtual_server::symlink_logged_as_domain_user(
				$d, $dirs[0], "$htmldir/$dir");
			}
		}
	use warnings "once";
	}

return undef;
}

# get_plugins_dir()
# Returns the directory in which plugins are stored
sub get_plugins_dir
{
my $pdir = $config{'plugins'};
if ($pdir && -d "$pdir/plugins") {
	$pdir .= "/plugins";
	}
if (!$pdir) {
	# In same dir as awstats.pl
	$config{'awstats'} =~ /^(.*)\//;
	$pdir = "$1/plugins";
	}
return $pdir;
}

# list_all_plugins()
# Returns a list of all available plugins, without the .pm extensions
sub list_all_plugins
{
my $pdir = &get_plugins_dir();
my @rv;
opendir(PLUGINS, $pdir);
foreach my $f (readdir(PLUGINS)) {
	if ($f =~ /^(\S+)\.pm$/) {
		push(@rv, $1);
		}
	}
closedir(PLUGINS);
return @rv;
}

# get_plugin_desc()
# Returns a human-readable description for some plugin
sub get_plugin_desc
{
my ($name) = @_;
my $file = &get_plugins_dir()."/".$name.".pm";
my $lref = &read_file_lines($file, 1);
my @cmts;
foreach my $l (@$lref) {
	if ($l =~ /^\#+\s*(.*)/ &&
	    $l !~ /^#!/ &&
	    $l !~ /^#+\s*\-\-/ &&
	    $l !~ /^#+\s*\$/ &&
	    $l !~ /^#+\s*\Q$name\E\s+AWStats\s+plugin/i &&
	    $l !~ /Required\s+Modules/i) {
		push(@cmts, $1);
		}
	last if ($l !~ /^#/);
	}
my $rv = join(" ", @cmts);
if ($name =~ /^geoip/ && $name ne "geoipfree") {
	$rv .= " <b>Requires commercial GeoIP data files</b>";
	}
return $rv;
}


1;

