#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use POSIX ":sys_wait_h";
use Time::HiRes "usleep";

require Fcntl::FileLock;
require File::Temp;

my $lock_path = File::Temp->new(CLEANUP => 1);
ok($lock_path, "lock_path = $lock_path");

my $child_pid = fork();
if (!defined $child_pid) { die "Failed to fork" };

if ($child_pid == 0) {
    my $file_lock = Fcntl::FileLock->new(path => $lock_path);
    $file_lock->lock;
    sleep 1;
    $file_lock->release;
}
else {
    ok($$, "parent pid = $$");
    ok($child_pid, "child pid = $child_pid");
    my $file_lock = Fcntl::FileLock->new(path => $lock_path);
    my $done = 0;
    do {
        usleep(250_000);
        my $child_done = waitpid($child_pid, WNOHANG);
        my $is_locked = $file_lock->is_locked;
        $done = ($child_done || $is_locked);
    } while not $done;
    my $is_already_locked = $file_lock->is_locked;
    is($is_already_locked, $child_pid, "is already locked by child");
    is($file_lock->lock, undef, 'failed to get lock');
    waitpid($child_pid, 0);
    is($file_lock->is_locked, 0, "is now unlocked");
    is($file_lock->lock, 1, 'got lock');

    done_testing();
}

