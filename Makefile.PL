use inc::Module::Install;

name     'DBIx-Class-Storage-CacheProxy';
all_from 'lib/DBIx/Class/Storage/CacheProxy.pm';
author   'Andrey Kostenko <andrey@kostenko.name>';

build_requires 'Test::More';

requires 'parent';
requires q/DBIx::Class/ => q/0.08010/;
requires q/Cache::Memcached/;
requires q/Digest::SHA/;
requires q/Storable/;


auto_install;

WriteAll;

