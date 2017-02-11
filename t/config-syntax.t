use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'config.cgi' );
strict_ok( 'config.cgi' );
warnings_ok( 'config.cgi' );
