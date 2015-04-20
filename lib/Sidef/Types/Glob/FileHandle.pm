package Sidef::Types::Glob::FileHandle {

    use 5.014;
    use parent qw(
      Sidef::Object::Object
      );

    sub new {
        my (undef, %opt) = @_;

        bless {
               fh   => $opt{fh},
               file => $opt{file},
              },
          __PACKAGE__;
    }

    sub get_value {
        $_[0]->{fh};
    }

    sub file {
        $_[0]{file};
    }

    *parent = \&file;

    sub is_on_tty {
        Sidef::Types::Bool::Bool->new(-t $_[0]{fh});
    }

    *isOnTty = \&is_on_tty;

    sub stdout {
        __PACKAGE__->new(fh => \*STDOUT);
    }

    sub stderr {
        __PACKAGE__->new(fh => \*STDERR);
    }

    sub stdin {
        __PACKAGE__->new(fh => \*STDIN);
    }

    sub autoflush {
        my ($self, $bool) = @_;
        select((select($self->{fh}), $| = $bool->get_value)[0]);
        $bool;
    }

    sub binmode {
        my ($self, $encoding) = @_;
        CORE::binmode($self->{fh}, $encoding->get_value);
    }

    sub compare {
        my ($self, $fh) = @_;
        $self->_is_fh($fh) || return;
        require File::Compare;
        Sidef::Types::Number::Number->new(File::Compare::compare($self->{fh}, $fh->{fh}));
    }

    *cmp = \&compare;

    sub writeString {
        my ($self, @args) = @_;

        @args <= 3 || do {
            warn "[WARN] FileHandle.writeString(): Too many arguments! Expected: (str, len, offset).";
            return;
        };

        Sidef::Types::Bool::Bool->new(syswrite $self->{fh}, @args);
    }

    *write_string = \&writeString;

    sub print {
        my ($self, @args) = @_;
        Sidef::Types::Bool::Bool->new(CORE::print {$self->{fh}} @args);
    }

    *write = \&print;
    *spurt = \&print;

    sub println {
        my ($self, @args) = @_;
        Sidef::Types::Bool::Bool->new(CORE::say {$self->{fh}} @args);
    }

    *say = \&println;

    sub read {
        my ($self, $var_ref, $length, $offset) = @_;

        my $var = $var_ref->get_var;
        my $chunk = $var->get_value->get_value // '';

        my $size = Sidef::Types::Number::Number->new(
                                                     defined($offset)
                                                     ? CORE::read($self->{fh}, $chunk, $length->get_value, $offset->get_value)
                                                     : CORE::read($self->{fh}, $chunk, $length->get_value)
                                                    );

        $var->set_value(Sidef::Types::String::String->new($chunk));

        return $size;
    }

    sub sysread {
        my ($self, $var_ref, $length, $offset) = @_;

        my $var = $var_ref->get_var;
        my $chunk = $var->get_value->get_value // '';

        my $size = Sidef::Types::Number::Number->new(
                                                   defined($offset)
                                                   ? CORE::sysread($self->{fh}, $chunk, $length->get_value, $offset->get_value)
                                                   : CORE::sysread($self->{fh}, $chunk, $length->get_value)
        );

        $var->set_value(Sidef::Types::String::String->new($chunk));

        return $size;
    }

    *sysRead = \&sysread;

    sub slurp {
        my ($self) = @_;

        my $size = (-s $self->{fh});
        if (not defined($size) or ($size == 0)) {
            local $/;
            return Sidef::Types::String::String->new(CORE::readline($self->{fh}));
        }

        CORE::sysread($self->{fh}, (my $content), $size);
        Sidef::Types::String::String->new($content);
    }

    sub readline {
        my ($self, $var_ref) = @_;

        if (defined $var_ref) {
            $self->_is_var_ref($var_ref) || return;
            my $line = CORE::readline($self->{fh});
            $var_ref->get_var->set_value(Sidef::Types::String::String->new($line // return Sidef::Types::Bool::Bool->false));
            return Sidef::Types::Bool::Bool->true;
        }

        Sidef::Types::String::String->new(CORE::readline($self->{fh}) // return);
    }

    *readln    = \&readline;
    *readLine  = \&readline;
    *read_line = \&readline;
    *get       = \&readline;
    *line      = \&readline;
    *get_line  = \&readline;
    *getLine   = \&readline;
    *getline   = \&readline;

    sub read_char {
        my ($self) = @_;

        my $char = getc($self->{fh});
        defined($char)
          ? Sidef::Types::Char::Char->new($char)
          : ();
    }

    *readChar = \&read_char;
    *getc     = \&read_char;
    *getChar  = \&read_char;
    *get_char = \&read_char;

    sub read_all {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(map { Sidef::Types::String::String->new($_) } CORE::readline($self->{fh}));
    }

    *readAll   = \*read_all;
    *readall   = \&read_all;
    *getlines  = \&read_all;
    *get_lines = \&read_all;
    *getLines  = \&read_all;
    *readlines = \&read_all;
    *readLines = \&read_all;
    *lines     = \&read_all;

    sub words {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(
            map {
                map    { Sidef::Types::String::String->new($_) }
                  grep { $_ ne '' }
                  split(' ', $_)
              } CORE::readline($self->{fh})
        );
    }

    sub each {
        my ($self, $code) = @_;
        my ($var_ref) = $code->init_block_vars();

        while (defined(my $line = CORE::readline($self->{fh}))) {
            $var_ref->set_value(Sidef::Types::String::String->new($line));
            if (defined(my $res = $code->_run_code)) {
                $code->pop_stack();
                return $res;
            }
        }

        $code->pop_stack();
        $self;
    }

    *each_line = \&each;

    sub eof {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(eof $self->{fh});
    }

    sub tell {
        my ($self) = @_;
        Sidef::Types::Number::Number->new(tell($self->{fh}));
    }

    sub seek {
        my ($self, $pos, $whence) = @_;
        Sidef::Types::Bool::Bool->new(seek($self->{fh}, $pos->get_value, $whence->get_value));
    }

    sub sysseek {
        my ($self, $pos, $whence) = @_;
        Sidef::Types::Bool::Bool->new(sysseek($self->{fh}, $pos->get_value, $whence->get_value));
    }

    *sysSeek = \&sysseek;

    sub fileno {
        my ($self) = @_;
        Sidef::Types::Number::Number->new(fileno($self->{fh}));
    }

    sub lock {
        my ($self) = @_;

        require Fcntl;
        $self->flock(Sidef::Types::Number::Number->new(&Fcntl::LOCK_EX));
    }

    sub unlock {
        my ($self) = @_;

        require Fcntl;
        $self->flock(Sidef::Types::Number::Number->new(&Fcntl::LOCK_UN));
    }

    sub flock {
        my ($self, $mode) = @_;
        Sidef::Types::Bool::Bool->new(CORE::flock($self->{fh}, $mode->get_value));
    }

    sub close {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(close $self->{fh});
    }

    sub stat {
        my ($self) = @_;
        Sidef::Types::Glob::Stat->stat($self->{fh}, $self);
    }

    sub lstat {
        my ($self) = @_;
        Sidef::Types::Glob::Stat->lstat($self->{fh}, $self);
    }

    sub truncate {
        my ($self, $length) = @_;
        my $len = defined($length) ? $length->get_value : 0;
        Sidef::Types::Bool::Bool->new(CORE::truncate($self->{fh}, $len));
    }

    sub separator {
        my ($self, $sep) = @_;

        my $old_sep = $/;
        $/ = $sep->get_value if defined($sep);

        Sidef::Types::String::String->new($old_sep);
    }

    *sep             = \&separator;
    *input_separator = \&separator;
    *inputSeparator  = \&separator;

    # File copy
    *copy = \&Sidef::Types::Glob::File::copy;
    *cp   = \&copy;

    sub read_to {
        my ($self, $var_ref) = @_;
        $self->_is_var_ref($var_ref) || return;
        $var_ref->get_var->set_value(Sidef::Types::String::String->new(unpack 'A*', scalar CORE::readline($self->{fh})));
        $self;
    }

    *readTo = \&read_to;

    sub output_from {
        my ($self, $string) = @_;
        CORE::print {$self->{fh}} $string;
        $self;
    }

    *outputFrom = \&output_from;

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . '>>'}  = \&read_to;
        *{__PACKAGE__ . '::' . '<<'}  = \&output_from;
        *{__PACKAGE__ . '::' . '<=>'} = \&compare;
    }

};

1
