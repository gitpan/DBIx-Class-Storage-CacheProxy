use lib 'libtest';
use Test::More tests=>7;
use CacheTest;
my $schema=CacheTest->connect("dbi:SQLite:test.sqlite");
my $test=$schema->resultset('Test');

$test->delete_all;
$test->create({id=>$_,name=>"bbb$_"}) foreach (1..10);

my @results=$test->search->all;
ok(@results==($test->search->all),'Comparing cached and uncached results');

is(scalar(@results),10,'Select all');

my $rs=$test->search;
my $is_next;
my $i=1;
my $row;
$is_next ||= ( $row->id==$i++ )  while $row=$rs->next;
ok($is_next,'Select next');

$test->search({'id'=>{'>'=>5}})->delete;
@results=$test->search->all;
is(scalar(@results),5,'Clearing cache on delete');

$test->find(4)->update({id=>6});
ok($test->find(6),'Clearing cache on update');

ok(!$test->find(4),'Clearing cache on update (one more)');

$test->create({id=>8,name=>'preved'});
ok($test->find(8),'Clearing cache on insert');
