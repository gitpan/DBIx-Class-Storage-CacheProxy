package DBIx::Class::Storage::CacheProxy;

use 5.008008;
use warnings;
use strict;
use Carp;
use parent qw/DBIx::Class::Storage::DBI Class::Accessor::Fast/;
use DBIx::Class::Storage::CacheProxy::Cursor;
use Storable qw/freeze thaw store/;
use Digest::SHA1 qw/sha1_hex/;
use Module::Load;

__PACKAGE__->mk_accessors(qw/cache/);
=head1 NAME

DBIx::Class::Storage::CacheProxy - Caching layer for DBIx::Class

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';




=head1 SYNOPSIS

Caching subsystem for DBIx::Class.

    package MyApp::Schema;
    use parent qw/DBIx::Class::Schema/;

    ...
    __PACKAGE__->storage_type('::CacheProxy'); # That's all (:
    ...

=head1 NOTE

This is unstable module.

=head1 METHODS

=head2 new

Creates new storage object.

=cut

sub new{
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->cursor_class('DBIx::Class::Storage::CacheProxy::Cursor');
    return $self;
}

=head2 connect_info

Params - cache => [ CLASSNAME, arguments to CLASSNAME->new]

=cut

sub connect_info{
    my $self=shift;
    if (@_ && (ref($_[0][-1]) eq 'HASH')){
	my $config=$_[0][-1]->{cache};
	$self->_connect_info_usage_cache
	    unless $config && (ref $config eq 'ARRAY') && @$config==2;
	my $class=__PACKAGE__."::Engine::".$config->[0];
	load $class;	
	$self->cache($class->new($config->[1]));
	return $self->SUPER::connect_info(@_);
    }
    $self->_connect_info_usage_cache;
}

sub _connect_info_usage_cache{
	die 'Usage: $schema->connect_info( ... , { cache=>[ CLASSNAME,{ ARGS } ] } )'."\n";
}

=head2 insert

Hook for insert. Clears cache for table. 

=cut

sub insert{
    my $self = shift;
    $self->_debug("Inserting item");
    $self->SUPER::insert(@_);
    $self->cache->clear_table_cache($_[0]->from)
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
	$self->cache->clear_table_cache($_[0]->from);
	return @res;
}

=head2 delete

Hook for delete. Work similar as update

=cut

sub delete{
	my $self=shift;
	$self->_debug("Deleting item(s)");
	$self->SUPER::delete(@_);
	$self->cache->clear_table_cache($_[0]->from);
}

=head2 select_single

Hook for selection of single row. Multiple rows support are in DBIx::Class::Storage::CacheProxy::Cursor

=cut

sub select_single{
    my $self=shift;
#    use Data::Dumper;
#    die Dumper $self->schema;
    my @args=@_;
    my @tables=values %{$args[0][0]};
    $self->_cache_proxy(\@_,\@tables,sub {
	$self->SUPER::select_single(@args) unless $ENV{DBIC_SELECT_FROM_CACHE};
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

sub _cache_proxy{
    my $self=shift;
    my $key=shift;
    my $tables=shift;
    confess "Param \$tables must be array reference\n" if ref($tables) ne "ARRAY";
    my $sub=shift;
    my $cache_sub=shift;
    $self->_debug("Searching in cache for key ".$self->_serialize_params($key));
    if (my $encoded_data=$self->cache->get($self->_serialize_params($key))){
	$self->_debug("Found in cache");
	$cache_sub->() if $cache_sub;
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
	$self->cache->store_into_table_cache(tables=>$tables,hash=>$key_hash,data=>$result_ref);
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

