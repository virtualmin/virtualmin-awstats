#!/usr/local/bin/perl
# Output an image for some AWstats domain

require './virtualmin-awstats-lib.pl';
&ReadParse();
&can_domain($in{'config'}) || &error($text{'view_ecannot'});
$path = $ENV{'PATH_INFO'};
$path =~ /\.\./ && &error($text{'view_epath'});
$path =~ /\0/ && &error($text{'view_epath'});
print "Content-type: ",&guess_mime_type($path),"\n\n";
&open_readfile(ICON, "$config{'icons'}$path");
while(<ICON>) {
	print $_;
	}
close(ICON);


