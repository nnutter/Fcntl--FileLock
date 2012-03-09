package Fcntl::FileLock;

use strict;
use warnings;

use IO::File;
use Fcntl;
use POSIX;

sub create { my $self = shift; return $self->new(@_); }
sub new {
    my $class = shift;
    my %params = @_;

    my $path = delete $params{path};
    unless ($path) { die "Must specify a path" };

    my $fh = delete $params{fh};
    unless ($fh) { $fh = IO::File->new($path, O_CREAT|O_RDWR) };

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

sub error {
    return shift->{error};
}

sub struct {
    my $self = shift;
    return $self->unpack_fcntl_struct(${$self->{struct_ref}})
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
    $self->{struct_ref} = \$struct;

    local $! = undef;
    my $lock = fcntl($self->fh, $cmd, $struct);
    my $error = $!;
    if ($error) {
        $self->{error} = $error;
    } else {
        $self->{error} = undef;
    }

    return (defined($lock) ? 1 : 0);
}

sub is_locked {
    my $self = shift;
    my $rv = $self->fcntl(F_GETLK, F_WRLCK);
    if ($self->struct->{type} != F_UNLCK) {
        return $self->struct->{pid};
    }
    else {
        return 0;
    }
}

sub lock_info {
    my $self = shift;
    my $fh = $self->fh;
    $fh->seek(0, 0);
    my $info = do { local $/; <$fh> };
    my @info = ($info ? split("\n", $info) : ());
    return \@info;
}

sub lock {
    my $self = shift;
    my $info = shift;

    my $got_lock = $self->fcntl(F_SETLK, F_WRLCK);
    return unless $got_lock;

    my $fh = $self->fh;
    print $fh $info if $info;
    return $got_lock;
}

sub lock_wait {
    my $self = shift;
    return $self->fcntl(F_SETLKW, F_WRLCK);
}

sub release {
    my $self = shift;
    my $fh = $self->fh;
    truncate($fh, 0);
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

    my $struct;
    if ($^O eq 'linux') {
        # short l_type;    /* Type of lock: F_RDLCK, F_WRLCK, F_UNLCK */
        # short l_whence;  /* How to interpret l_start: SEEK_SET, SEEK_CUR, SEEK_END */
        # off_t l_start;   /* Starting offset for lock */
        # off_t l_len;     /* Number of bytes to lock */
        # pid_t l_pid;     /* PID of process blocking our lock (F_GETLK only) */
        $struct = pack('s s l l s', $type, $whence, $start, $len, $pid);
    } elsif ($^O eq 'darwin') {
        die "Sorry I don't know how to pack the flock struct on $^O"; # doesn't work yet
        # off_t       l_start;    /* starting offset */
        # off_t       l_len;      /* len = 0 means until end of file */
        # pid_t       l_pid;      /* lock owner */
        # short       l_type;     /* lock type: read/write, etc. */
        # short       l_whence;   /* type of l_start */
        $struct = pack('q q i s s', $start, $len, $pid, $type, $whence);
    } else {
        die "Sorry I don't know how to pack the flock struct on $^O";
    }

    return $struct;
}

sub unpack_fcntl_struct {
    my $self = shift;
    my $struct = shift;
    unless ($struct) { die "Must pass a struct in" };

    my ($type, $whence, $start, $len, $pid);
    if ($^O eq 'linux') {
        ($type, $whence, $start, $len, $pid) = unpack('s s l l s', $struct);
    } elsif ($^O eq 'darwin') {
        ($start, $len, $pid, $type, $whence) = unpack('l l i s s', $struct);
    } else {
        die "Sorry I don't know how to pack the flock struct on $^O";
    }
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
