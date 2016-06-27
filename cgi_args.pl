use strict;
use warnings;
our $module_name;

do 'virtualmin-awstats-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
&foreign_require("virtual-server", "virtual-server-lib.pl");
my ($d) = grep { &virtual_server::can_edit_domain($_) &&
		  $_->{$module_name} } &virtual_server::list_domains();
if ($cgi eq 'config.cgi') {
	return $d ? 'dom='.&urlize($d->{'dom'}) : 'none';
	}
elsif ($cgi eq 'view.cgi') {
	return $d ? 'config='.&urlize($d->{'dom'}) : 'none';
	}
return undef;
}
