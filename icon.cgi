#!/usr/local/bin/perl
# Output an image for some AWStats domain
use strict;
use warnings;
our (%text, %in, %config);

require './virtualmin-awstats-lib.pl';
&ReadParse();
&can_domain($in{'config'}) || &error($text{'view_ecannot'});
my $path = $ENV{'PATH_INFO'};
$path =~ /\.\./ && &error($text{'view_epath'});
$path =~ /\0/ && &error($text{'view_epath'});
print "Content-type: ",&guess_mime_type($path),"\n\n";
no strict "subs";
&open_readfile(ICON, "$config{'icons'}$path");
while(<ICON>) {
	print $_;
	}
close(ICON);
use strict "subs";

