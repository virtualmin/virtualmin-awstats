use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'config_save.cgi' );
strict_ok( 'config_save.cgi' );
warnings_ok( 'config_save.cgi' );
