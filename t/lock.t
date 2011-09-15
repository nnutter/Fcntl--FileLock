#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use POSIX ":sys_wait_h";
use Time::HiRes "usleep";

require Fcntl::FileLock;
require File::Temp;

my $lock_path = File::Temp->new(CLEANUP => 1);

my $child_pid = fork();
if (!defined $child_pid) { die "Failed to fork" };

if ($child_pid == 0) {
    my $file_lock = Fcntl::FileLock->new(path => $lock_path);
    $file_lock->lock;
    sleep 2;
    $file_lock->release;
}
else {
    my $file_lock = Fcntl::FileLock->new(path => $lock_path);

    my $done = 0;
    do {
        my $child_done = waitpid($child_pid, WNOHANG);
        my $is_locked = $file_lock->is_locked;
        $done = ($child_done || $is_locked);
    } while not $done;
    is($file_lock->lock, undef, 'failed to lock ' . $lock_path);
    waitpid($child_pid, 0);
    is($file_lock->lock, 1, 'locked ' . $lock_path);

    done_testing();
}

