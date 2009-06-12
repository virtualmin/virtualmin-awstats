
do 'virtualmin-awstats-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
&foreign_require("virtual-server", "virtual-server-lib.pl");
my ($d) = grep { &virtual_server::can_edit_domain($_) &&
		  $_->{$module_name} } &virtual_server::list_domains();
return undef if (!$d);
if ($cgi eq 'config.cgi') {
	return 'dom='.&urlize($d->{'dom'});
	}
elsif ($cgi eq 'view.cgi') {
	return 'config='.&urlize($d->{'dom'});
	}
return undef;
}
