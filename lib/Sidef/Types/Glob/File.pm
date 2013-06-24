
use 5.014;
use strict;
use warnings;

package Sidef::Types::Glob::File {

    use parent qw(Sidef::Convert::Convert);

    sub new {
        my (undef, $file) = @_;
        $file = $$file if ref $file;
        bless \$file, __PACKAGE__;
    }

    sub get_value {
        ${$_[0]};
    }

    sub size {
        my ($self) = @_;
        Sidef::Types::Number::Number->new(-s $$self);
    }

    sub exists {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(-e $$self);
    }

    sub is_binary {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(-B $$self);
    }

    sub is_text {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(-T $$self);
    }

    sub is_file {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(-f $$self);
    }

    sub name {
        my ($self) = @_;
        Sidef::Types::String::String->new($$self);
    }

    sub basename {
        my ($self) = @_;

        require File::Basename;
        Sidef::Types::String::String->new(File::Basename::basename($$self));
    }

    sub dirname {
        my ($self) = @_;

        require File::Basename;
        Sidef::Types::Glob::Dir->new(File::Basename::dirname($$self));
    }

    sub abs_name {
        my ($self) = @_;

        require Cwd;
        __PACKAGE__->new(Cwd::abs_path($$self));
    }

    sub open {
        my ($self, $mode) = @_;
        $mode = ${$mode} if ref $mode;

        open my $fh, $mode, $$self;
        Sidef::Types::Glob::FileHandle->new(fh => $fh, file => $self);
    }

    sub open_r {
        my ($self) = @_;
        $self->open('<');
    }

    sub open_w {
        my ($self) = @_;
        $self->open('>');
    }

    sub open_a {
        my ($self) = @_;
        $self->open('>>');
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('File.new(' . ${Sidef::Types::String::String->new($$self)->dump} . ')');
    }
};

1;
