package DBIx::Class::Storage::CacheProxy;

use 5.8.8;
use warnings;
use strict;
use Carp;
use parent qw/DBIx::Class::Storage::DBI Class::Accessor::Fast/;
use DBIx::Class::Storage::CacheProxy::Cursor;
use Cache::Memcached;
use Storable qw/freeze thaw store/;
use Digest::SHA1 qw/sha1_hex/;

__PACKAGE__->mk_accessors(qw/cache/);
$Carp::CarpLevel=0;
=head1 NAME

DBIx::Class::Storage::CacheProxy - Caching layer for DBIx::Class

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';




=head1 SYNOPSIS

Caching subsystem for DBIx::Class.

    package MyApp::Schema;
    use parent qw/DBIx::Class::Schema/;

    ...
    __PACKAGE__->storage_type('::CacheProxy'); # That's all (:
    ...

=head1 METHODS

=head2 new

Creates new storage object.

=cut

sub new{
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->cache(new Cache::Memcached({servers=>['127.0.0.1:11211']}));
    $self->cursor_class('DBIx::Class::Storage::CacheProxy::Cursor');
    return $self;
}

=head2 insert

Hook for insert. Clears cache for table. 

=cut

sub insert{
    my $self = shift;
    $self->_debug("Inserting item");
    $self->SUPER::insert(@_);
    $self->_clear_table_cache($_[0]->from)
}

=head2 update

Hook for update. Clears cache for table+cache for modified items (if it can)

=cut

sub update{
	my $self=shift;
	my @res;
	$self->_debug("Updating item(s)");
	if (wantarray){
		@res=($self->SUPER::update(@_));
	} else {
		@res=scalar($self->SUPER::update(@_));
	}
	$self->_clear_table_cache($_[0]->from);
	return @res;
}

=head2 delete

Hook for delete. Work similar as update

=cut

sub delete{
	my $self=shift;
	$self->_debug("Deleting item(s)");
	$self->SUPER::delete(@_);
	$self->_clear_table_cache($_[0]->from);
}

=head2 select_single

Hook for selection of single row. Multiple rows support are in DBIx::Class::Storage::CacheProxy::Cursor

=cut

sub select_single{
    my $self=shift;
    my @args=@_;
    my @tables=values %{$args[0][0]};
    $self->_cache_proxy(\@_,\@tables,sub {
	$self->SUPER::select_single(@args);
    });
}


sub _debug {
	shift();
#	carp shift()."\n";
}


sub _serialize_params{
    my $self=shift;
    my $params=shift;
    sha1_hex(freeze($params));
}

sub _store_into_table_cache{
	my $self=shift;
	$self->_debug("Appending to table cache");
	my %params=@_;
	my $tables=$params{tables};
	my %tables=map {$_=>1} @$tables;
	my $key=$params{hash};
	# получаем количество закэшированных записей для данной таблицы
	# дописываем новый ключ в конец массива
	# схема:
	# table_cache:sessions -> 10 превращается в 11
	# table_cache_row:sessions:1 -> somekey -> DATA
	# ...
	# table_cache_row:sessions:10 -> somekey -> DATA
	# table_cache_row:sessions:11 -> somekey -> DATA <==== оце ми пишемо
	# для кожної таблиці:
	foreach my $table (keys %tables){
		$self->_debug("=>	$table");
		$self->cache->add("table_cache:$table",0);# а може ії немає
		my $row=$self->cache->incr("table_cache:$table");# тільки incr/decr атомарні
		$self->cache->set("table_cache_row:$table:$row"=>$key);
	}
}

sub _clear_table_cache{
	my $self=shift;
	$self->_debug("Clearing table cache");
	my $table=shift; # тільки одня таблиця. боронь мене боже від багатьох таблиць T_T
	my $cache=$self->cache;
	return unless my $array_size=$cache->get("table_cache:$table");
	$self->cache->delete("table_cache:$table");
	foreach my $row (1..$array_size){
		my $data_ptr=$cache->get("table_cache_row:$table:$row");
		$self->_debug("=>	[$row] $data_ptr");
		$cache->delete("table_cache_row:$table:$row");
		$cache->delete("$data_ptr");
	}
	
}

sub _cache_proxy{
    my $self=shift;
    my $key=shift;
    my $tables=shift;
    confess "Param \$tables must be array reference\n" if ref($tables) ne "ARRAY";
    my $sub=shift;
    $self->_debug("Searching in cache for key ".$self->_serialize_params($key));
    if (my $encoded_data=$self->cache->get($self->_serialize_params($key))){
	$self->_debug("Found in cache");
	my $cached_data = $encoded_data;
	if (ref $cached_data eq 'SCALAR'){
	    $self->_debug("    (scalar)");
	    return $$cached_data;
	} elsif (ref $cached_data eq 'ARRAY'){
	    $self->_debug("    (array)");
	    return @$cached_data;
	}
    } else {
	my $result_ref;
	if (wantarray){
	    my @result=$sub->();
	    $result_ref=\@result;
	} else {
	    my $result=$sub->();
	    $result_ref=\$result;
	}
	$self->_debug("Storing data");
	my $key_hash=$self->_serialize_params($key);
	$self->cache->set($key_hash=>$result_ref);
	$self->_store_into_table_cache(tables=>$tables,hash=>$key_hash);
	return wantarray ? @$result_ref : $$result_ref;
    }
}


=head1 AUTHOR

Andrey Kostenko, C<< <andrey at kostenko.name> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-class-storage-cacheproxy at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Class-Storage-CacheProxy>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Class::Storage::CacheProxy


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Class-Storage-CacheProxy>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Class-Storage-CacheProxy>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Class-Storage-CacheProxy>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Class-Storage-CacheProxy>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of DBIx::Class::Storage::CacheProxy

