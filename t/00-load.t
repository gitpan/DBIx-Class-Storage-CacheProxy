#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::Class::Storage::CacheProxy' );
}

diag( "Testing DBIx::Class::Storage::CacheProxy $DBIx::Class::Storage::CacheProxy::VERSION, Perl $], $^X" );
