use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'generate.cgi' );
strict_ok( 'generate.cgi' );
warnings_ok( 'generate.cgi' );
