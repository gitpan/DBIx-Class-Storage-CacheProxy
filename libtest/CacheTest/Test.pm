package CacheTest::Test;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/Core PK::Auto/);
__PACKAGE__->table('test');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key('id');
1;
