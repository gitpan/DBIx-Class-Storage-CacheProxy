use inc::Module::Install;

name     'DBIx-Class-Storage-CacheProxy';
all_from 'lib/DBIx/Class/Storage/CacheProxy.pm';
author   'Andrey Kostenko <andrey@kostenko.name>';

build_requires 'Test::More';

requires 'parent';
requires q/DBIx::Class/ => q/0.08010/;
recommends q/Cache::Memcached/;
recommends q/Cache::FastMmap/;
test_requires q/Cache::FastMmap/;
requires q/Digest::SHA/;
requires q/Storable/;
no_index q/libtest/;
test_requires 'DBD::SQLite';

auto_install;

WriteAll;

