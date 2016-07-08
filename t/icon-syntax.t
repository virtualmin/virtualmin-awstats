use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'icon.cgi' );
strict_ok( 'icon.cgi' );
warnings_ok( 'icon.cgi' );
