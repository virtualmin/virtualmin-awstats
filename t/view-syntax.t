use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'view.cgi' );
strict_ok( 'view.cgi' );
warnings_ok( 'view.cgi' );
