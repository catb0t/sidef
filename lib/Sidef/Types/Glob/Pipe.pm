
use 5.014;
use strict;
use warnings;

# NEEDS WORK!!!

package Sidef::Types::Glob::Pipe {

    sub new {
        my ($class, $command) = @_;
        $command = $$command   if ref $command;
        $class   = ref($class) if ref($class);
        bless \$command, $class;
    }

    sub command {
        my ($self) = @_;
        Sidef::Types::String::String->new($$self);
    }

    sub open {
        my ($self, $mode) = @_;
        $mode = $$mode if ref($mode);

        open my $pipe_h, $mode, $$self;
        Sidef::Types::Glob::PipeHandle->new(pipe_h => $pipe_h, pipe => $self);
    }

    sub open_r {
        my ($self) = @_;
        $self->open('-|');
    }

    sub open_w {
        my ($self) = @_;
        $self->open('|-');
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('Pipe.new(' . ${Sidef::Types::String::String->new($$self)->dump} . ')');
    }

};

1;
