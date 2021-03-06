package Fcntl::FileLock;

use strict;
use warnings;

use Fcntl;
use POSIX;

sub create { my $self = shift; return $self->new(@_); }
sub new {
    my $class = shift;
    my %params = @_;

    my $path = delete $params{path};
    unless ($path) { die "Must specify a path" };

    my $fh = delete $params{fh};
    unless ($fh) { sysopen($fh, $path, O_CREAT|O_RDWR) };

    # even when sysopen returns set $fh there may have been errors
    # such as permission issues but ENOTTY is OK (no TTY)
    unless ($fh) { die "Failed to open file handle" };
    if ($! && $! != ENOTTY) { die $! };

    my $object = {path => $path, fh => $fh};

    return bless $object, $class;
}

sub path {
    my $self = shift;
    return $self->{path};
}

sub fh {
    my $self = shift;
    return $self->{fh};
}

sub fcntl {
    my $self = shift;
    my $cmd = shift;
    my $type = shift;

    unless(defined $cmd) {
        die "A lock command must be specified.\n";
    }
    unless(defined $type) {
        die "A lock type must be specified.\n";
    }

    my $struct = $self->create_fcntl_struct(type => $type);
    my $lock = fcntl($self->fh, $cmd, $struct);

    my $rv = (defined($lock) ? 1 : 0);
    if (wantarray) {
        return ($rv, $struct);
    }
    else {
        return $rv;
    }
}

sub is_locked {
    my $self = shift;
    my $type = shift || F_WRLCK;
    my ($rv, $struct) = $self->fcntl(F_GETLK, $type);
    my $struct_hash = $self->unpack_fcntl_struct($struct);
    if ($struct_hash->{type} != F_UNLCK) {
        return $struct_hash->{pid};
    }
    else {
        return 0;
    }
}

sub lock {
    my $self = shift;
    my $type = shift || F_WRLCK;
    return $self->fcntl(F_SETLK, $type);
}

sub lock_wait {
    my $self = shift;
    my $type = shift || F_WRLCK;
    return $self->fcntl(F_SETLKW, $type);
}

sub release {
    my $self = shift;
    return $self->fcntl(F_SETLK, F_UNLCK);
}

sub create_fcntl_struct {
    my $self = shift;
    my %params = @_;

    my $type = delete $params{type};
    unless ($type) { die "Must specify type of lock (e.g. F_SETLK, F_UNLCK, F_WRLCK)" };

    # defaults to locking whole file
    my $whence = delete $params{whence} || 0;
    my $start = delete $params{start} || 0;
    my $len = delete $params{len} || 0;

    # defaults to current process pid
    my $pid = delete $params{pid} || $$;

    my $struct = pack('s s l l s', $type, $whence, $start, $len, $pid);

    return $struct;
}

sub unpack_fcntl_struct {
    my $self = shift;
    my $struct = shift;
    unless ($struct) { die "Must pass a struct in" };

    my ($type, $whence, $start, $len, $pid) = unpack('s s l l s', $struct);
    my $struct_hash = {
        type => $type,
        whence => $whence,
        start => $start,
        len => $len,
        pid => $pid,
    };
    return $struct_hash;
}

1;
