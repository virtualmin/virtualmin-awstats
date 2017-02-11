use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'run-all-awstats.pl' );
strict_ok( 'run-all-awstats.pl' );
warnings_ok( 'run-all-awstats.pl' );
