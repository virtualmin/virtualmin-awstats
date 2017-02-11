#!/usr/local/bin/perl
# Run AWstats to show the stats for some domain
use strict;
use warnings;
our (%text, %in, %config);

require './virtualmin-awstats-lib.pl';
&ReadParse();
$in{'config'} =~ s/\0.*$//g;
&can_domain($in{'config'}) || &error($text{'view_ecannot'});
my $conf = &get_config($in{'config'});
my $prog = &find_value("WrapperScript", $conf);
$prog ||= "awstats.pl";
my $icons = &find_value("DirIcons", $conf);

$ENV{'SERVER_NAME'} = $in{'config'};
$ENV{'GATEWAY_INTERFACE'} = "CGI";
no strict "subs"; # XXX Lexical?
&open_execute_command(AWSTATS, $config{'awstats'}, 1, 1);
while(<AWSTATS>) {
	# Replace references to awstats.pl with links to this CGI
	s/$prog/view.cgi/g;
	if (!/view.cgi\?config=/) {
                if (/\&amp;/) {
                        s/view.cgi\?/view.cgi?config=$in{'config'}\&amp;/g ||
                          s/view.cgi/view.cgi?config=$in{'config'}/g;
                        }
                else {
                        s/view.cgi\?/view.cgi?config=$in{'config'}\&/g ||
                          s/view.cgi/view.cgi?config=$in{'config'}/g;
                        }
		}

	# Replace references to icons with icon getter CGI
	s/$icons(\/\S+\.(gif|png|jpg))/icon.cgi$1?config=$in{'config'}/ig;

	print;
	}
close(AWSTATS);
use strict "subs";
