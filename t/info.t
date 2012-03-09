#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

require Fcntl::FileLock;
require File::Temp;

my $lock_path = File::Temp->new(CLEANUP => 1);
ok($lock_path, "lock_path = $lock_path");

my $file_lock = Fcntl::FileLock->new(path => $lock_path);
isa_ok($file_lock, 'Fcntl::FileLock', 'file_lock');

my $info = ['HOST foo', 'USER bob'];
is($file_lock->lock(join "\n", @$info), 1, 'got lock');
is_deeply($file_lock->lock_info, $info, 'lock info was set');

is($file_lock->release, 1, 'released lock') || warn $file_lock->error;
is_deeply($file_lock->lock_info, [], 'lock info was cleared');

done_testing();
