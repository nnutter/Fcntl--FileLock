package Fcntl::FileLock;

use strict;
use warnings;

use Fcntl;

sub create { my $self = shift; return $self->new(@_); }
sub new {
    my $class = shift;
    my %params = @_;

    my $path = delete $params{path};
    unless ($path) { die "Must specify a path" };

    my $fh = delete $params{fh};
    unless ($fh) { sysopen($fh, $path, O_CREAT|O_RDWR) };
    unless ($fh) { die "Failed to open file handle" };

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
    my $lock = fcntl($self->fh, F_SETLK, $struct);

    return (defined $lock);
}

sub is_locked {
    my $self = shift;
    my $type = shift || F_WRLCK;
    return $self->fcntl(F_GETLK, $type);
}

sub lock {
    my $self = shift;
    my $type = shift || F_WRLCK;
    return $self->fcntl(F_SETLK, $type);
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

1;
