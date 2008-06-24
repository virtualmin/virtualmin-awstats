# Functions for configuring AWstats

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();

$cron_cmd = "$module_config_directory/awstats.pl";
$run_as_file = "$module_config_directory/runas";

# list_configs()
# Returns a list of domains for which AWstats is configured
sub list_configs
{
local @rv;
local $dir = &translate_filename($config{'config_dir'});
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
# Parses the AWstats configuration for some virtual server into a array ref of
# values.
sub get_config
{
local ($dom) = @_;
if (!defined($get_config_cache{$dom})) {
	local @rv;
	local $lnum = 0;
	local $cfile = &get_config_file($dom);
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
	$get_config_cache{$dom} = \@rv;
	}
return $get_config_cache{$dom};
}

# get_config_file(domain)
# Returns the AWstats config file for some domain
sub get_config_file
{
return "$config{'config_dir'}/awstats.$_[0].conf";
}

# find_value(name, &conf)
# Returns the value of some AWstats directive
sub find_value
{
local ($name, $conf) = @_;
local ($dir) = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return $dir ? $dir->{'value'} : undef;
}

# save_directive(&config, domain, name, value)
# Updates some value in the AWstats config
sub save_directive
{
local ($conf, $dom, $name, $value) = @_;
local $file = &get_config_file($dom);
local $lref = &read_file_lines($file);
local ($dir) = grep { lc($_->{'name'}) eq lc($name) } @$conf;
local $line;
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

# delete_config(domain)
# Deletes the config for one domain
sub delete_config
{
local ($dom) = @_;
&unlink_logged(&get_config_file("www.".$dom));
&unlink_logged(&get_config_file($dom));
}

# can_domain(domain)
# Returns 1 if the current user can manage some AWstats domain
sub can_domain
{
return 1 if ($access{'domains'} eq '*');
local %can = map { $_, 1 } split(/\s+/, $access{'domains'});
return $can{$_[0]};
}

# awstats_model_file()
# Returns the full path to the template AWstats config file, or undef if none
sub awstats_model_file
{
foreach my $f ("awstats.model.conf", "awstats.conf") {
	local $p = "$config{'config_dir'}/$f";
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
local ($dom) = @_;
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq "$cron_cmd $dom" } @jobs;
return $job;
}

# get_run_user(domain)
# Returns the user to run awstats as for some domain, from the module's
# internal list
sub get_run_user
{
local %runas;
&read_file_cached($run_as_file, \%runas);
return $runas{$_[0]} || "root";
}

# save_run_user(domain, user)
sub save_run_user
{
local %runas;
&read_file_cached($run_as_file, \%runas);
$runas{$_[0]} = $_[1];
&write_file($run_as_file, \%runas);
}

# rename_run_domain(domain, olddomain)
sub rename_run_domain
{
local %runas;
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
local %runas;
&read_file_cached($run_as_file, \%runas);
delete($runas{$_[0]});
&write_file($run_as_file, \%runas);
}

# generate_report(domain, handle, html-escape?)
# Updates the AWstats report for a particular domain, from all of its
# log files (or at least those that have changed since the last run)
sub generate_report
{
local ($dom, $fh, $esc) = @_;
local $user = &get_run_user($dom);
local $cmd = "$config{'awstats'} -config=$dom -update";
$ENV{'GATEWAY_INTERFACE'} = undef;

# Find all the log files
local $conf = &get_config($dom);
local $baselog = &find_value("LogFile", $conf);
local @all = $baselog =~ /\|$/ ? ( undef ) : &all_log_files($baselog);

# Find last modified time for each log file
local ($a, %mtime);
foreach $a (@all) {
	local @st = stat($a);
	$mtime{$a} = $st[9];
	}

# Do each log file that we haven't already done
local $anyok = 0;
foreach $a (sort { $mtime{$a} <=> $mtime{$b} } @all) {
	local $fullcmd = $cmd;
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
	$fullcmd .= "2>&1";
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
	$anyok = 1 if (!$?);
	&additional_log("exec", undef, $fullcmd);
	}

# Link all awstatsXXXX.domain.txt files to awstatsXXXX.www.domain.txt , so
# that the URL www.domain.com/awstats/awstats.pl works
local $dirdata = &find_value("DirData", $conf);
&link_domain_alias_data($dom, $dirdata, $user);

return $anyok;
}

# link_domain_alias_data(domain, data-dir, user)
# Create symlinks from all awstatsXXXX.domain.txt files to
# awstatsXXXX.www.domain.txt , so that the URL
# www.domain.com/awstats/awstats.pl works. If the domain is used by Virtualmin,
# alias link up any aliases of this domain
sub link_domain_alias_data
{
local ($dom, $dirdata, $user) = @_;
local @otherdoms = ( "www.".$dom );
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	local $d = &virtual_server::get_domain_by("dom", $dom);
	if ($d) {
		foreach my $ad (&virtual_server::get_domain_by(
				"alias", $d->{'id'})) {
			push(@otherdoms, $ad->{'dom'}, "www.".$ad->{'dom'});
			}
		}
	}
opendir(DIRDATA, $dirdata);
foreach my $f (readdir(DIRDATA)) {
	if ($f =~ /^awstats(\d+)\.\Q$dom\E\.txt$/) {
		foreach my $other (@otherdoms) {
			local $wwwf = "awstats".$1.".".$other.".txt";
			if (!-r "$dirdata/$wwwf") {
				&symlink_logged($f, "$dirdata/$wwwf");
				&set_ownership_permissions($user, undef, undef,
							   "$dirdata/$wwwf");
				}
			}
		}
	}
closedir(DIRDATA);
}

# unlink_domain_alias_data(domain-name, directory)
# Remove any symbolic links for AWstats data files for some domain
sub unlink_domain_alias_data
{
local ($aliasdom, $dirdata) = @_;
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
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^\Q$base\E/ && -f "$dir/$f") {
		push(@rv, "$dir/$f");
		}
	}
closedir(DIR);
return @rv;
}

1;

