package CacheTest;
use parent 'DBIx::Class::Schema';

__PACKAGE__->storage_type('::CacheProxy');
__PACKAGE__->load_classes;
1;
