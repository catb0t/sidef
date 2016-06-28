package Sidef::Types::Glob::File {

    use 5.014;

    use parent qw(
      Sidef::Convert::Convert
      Sidef::Types::String::String
      );

    use Sidef::Types::Number::Number;

    sub new {
        my (undef, $file) = @_;
        if (@_ > 2) {
            state $x = require File::Spec;
            $file = File::Spec->catfile(map { "$_" } @_[1 .. $#_]);
        }
        elsif (ref($file) && ref($file) ne 'SCALAR') {
            $file = "$file";
        }
        bless \$file, __PACKAGE__;
    }

    *call = \&new;

    sub get_value { ${$_[0]} }
    sub to_file   { $_[0] }

    {
        no strict 'refs';
        require Fcntl;

        my %cache;
        foreach my $name (@Fcntl::EXPORT, @Fcntl::EXPORT_OK) {
            $name =~ /^[a-z]/i or next;
            *{__PACKAGE__ . '::' . $name} = sub {
                $cache{$name} //= Sidef::Types::Number::Number::_new_uint(&{'Fcntl::' . $name});
            };
        }
    }

    sub touch {
        my ($self, @args) = @_;

        if (not ref($self)) {
            $self = $self->new(shift @args);
        }

        $self->open('>>', @args);
    }

    *make   = \&touch;
    *mkfile = \&touch;
    *create = \&touch;

    sub size {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        Sidef::Types::Number::Number->new(-s "$self");
    }

    sub compare {
        ref($_[0]) || shift(@_);
        my ($self, $file) = @_;
        state $x = require File::Compare;
        my $cmp = File::Compare::compare("$self", "$file");

            $cmp < 0 ? Sidef::Types::Number::Number::MONE
          : $cmp > 0 ? Sidef::Types::Number::Number::ONE
          :            Sidef::Types::Number::Number::ZERO;
    }

    sub exists {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-e "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_empty {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-z "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_directory {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-d "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_dir = \&is_directory;

    sub is_link {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-l "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub readlink {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        Sidef::Types::String::String->new(CORE::readlink("$self"));
    }

    *read_link = \&readlink;

    sub is_socket {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-S "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_block {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-b "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_char_device {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-c "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_readable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-r "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_writeable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-w "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub has_setuid_bit {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-u "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub has_setgid_bit {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-g "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub has_sticky_bit {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-k "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub modification_time_days_diff {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-M "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub access_time_days_diff {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-A "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub change_time_days_diff {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-C "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_executable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-x "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_owned {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-o "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_real_readable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-R "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_real_writeable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-W "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_real_executable {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-X "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_real_owned {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-O "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_binary {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-B "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_text {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-T "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_file {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        (-f "$self") ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub name {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        Sidef::Types::String::String->new("$self");
    }

    sub basename {
        ref($_[0]) || shift(@_);
        my ($self) = @_;

        state $x = require File::Basename;
        Sidef::Types::String::String->new(File::Basename::basename("$self"));
    }

    *base      = \&basename;
    *base_name = \&basename;

    sub dirname {
        ref($_[0]) || shift(@_);
        my ($self) = @_;

        state $x = require File::Basename;
        Sidef::Types::Glob::Dir->new(File::Basename::dirname("$self"));
    }

    *dir      = \&dirname;
    *dir_name = \&dirname;

    sub is_absolute {
        ref($_[0]) || shift(@_);
        my ($self) = @_;

        state $x = require File::Spec;
        File::Spec->file_name_is_absolute("$self")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_abs = \&is_absolute;

    sub abs_name {
        my ($self) = @_;

        unless (ref($self)) {
            $self = $self->new($_[1]);
        }

        state $x = require File::Spec;
        $self->new(File::Spec->rel2abs("$self"));
    }

    *abs     = \&abs_name;
    *absname = \&abs_name;
    *rel2abs = \&abs_name;

    sub rel_name {
        my ($self, $base) = @_;

        unless (ref($self)) {
            ($self, $base) = ($self->new($base), $_[2]);
        }

        state $x = require File::Spec;
        $self->new(File::Spec->rel2abs("$self", defined($base) ? "$base" : ()));
    }

    *rel     = \&rel_name;
    *relname = \&rel_name;
    *abs2rel = \&rel_name;

    sub rename {
        ref($_[0]) || shift(@_);
        my ($self, $file) = @_;

        CORE::rename("$self", "$file")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub move {
        ref($_[0]) || shift(@_);
        my ($self, $file) = @_;

        state $x = require File::Copy;
        File::Copy::move("$self", "$file")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *mv = \&move;

    sub copy {
        ref($_[0]) || shift(@_);
        my ($self, $file) = @_;

        state $x = require File::Copy;
        File::Copy::copy("$self", "$file")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *cp = \&copy;

    sub edit {
        ref($_[0]) || shift(@_);
        my ($self, $code) = @_;

        my @lines;
        open(my $fh, '+<:utf8', "$self") || return (Sidef::Types::Bool::Bool::FALSE);
        while (defined(my $line = <$fh>)) {
            push @lines, $code->run(Sidef::Types::String::String->new($line));
        }

        truncate($fh, 0) || do {
            warn "[WARN] Can't truncate file `$self': $!";
            return;
        };

        seek($fh, 0, 0) || do {
            warn "[WARN] Can't seek the begining of file `$self': $!";
            return;
        };

        do {
            local $, = q{};
            local $\ = q{};
            print $fh @lines;
            close $fh;
          }
          ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub open {
        ref($_[0]) || shift(@_);
        my ($self, $mode, $fh_ref, $err_ref) = @_;

        $mode = "$mode" if (ref $mode);

        my $success = CORE::open(my $fh, $mode, "$self");
        my $error   = $!;
        my $fh_obj  = Sidef::Types::Glob::FileHandle->new(fh => $fh, self => $self);

        if (defined $fh_ref) {
            ${$fh_ref} = $fh_obj;

            return $success
              ? (Sidef::Types::Bool::Bool::TRUE)
              : do {
                defined($err_ref) && do { ${$err_ref} = Sidef::Types::String::String->new($error) };
                (Sidef::Types::Bool::Bool::FALSE);
              };
        }

        $success ? $fh_obj : ();
    }

    sub open_r {
        my ($self, @rest) = @_;
        unless (ref($_[0])) {
            $self = $self->new(shift @rest);
        }
        $self->open('<:utf8', @rest);
    }

    *open_read = \&open_r;

    sub open_w {
        my ($self, @rest) = @_;
        unless (ref($_[0])) {
            $self = $self->new(shift @rest);
        }
        $self->open('>:utf8', @rest);
    }

    *open_write = \&open_w;

    sub open_a {
        my ($self, @rest) = @_;
        unless (ref($_[0])) {
            $self = $self->new(shift @rest);
        }
        $self->open('>>:utf8', @rest);
    }

    *open_append = \&open_a;

    sub open_rw {
        my ($self, @rest) = @_;
        unless (ref($_[0])) {
            $self = $self->new(shift @rest);
        }
        $self->open('+<:utf8', @rest);
    }

    *open_read_write = \&open_rw;

    sub opendir {
        ref($_[0]) || shift(@_);
        my ($self, @rest) = @_;
        Sidef::Types::Glob::Dir->new("$self")->open(@rest);
    }

    sub sysopen {
        ref($_[0]) || shift(@_);
        my ($self, $var_ref, $mode, $perm) = @_;

        my $success = sysopen(my $fh, "$self", "$mode", $perm // 0666);

        if ($success) {
            $$var_ref = Sidef::Types::Glob::FileHandle->new(fh => $fh, self => $self);
        }

        $success
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub stat {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        Sidef::Types::Glob::Stat->stat("$self", $self);
    }

    sub lstat {
        ref($_[0]) || shift(@_);
        my ($self) = @_;
        Sidef::Types::Glob::Stat->lstat("$self", $self);
    }

    sub chown {
        ref($_[0]) || shift(@_);
        my ($self, $uid, $gid) = @_;
        CORE::chown($uid, $gid, "$self")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub chmod {
        ref($_[0]) || shift(@_);
        my ($self, $permission) = @_;
        CORE::chmod($permission, "$self")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub utime {
        ref($_[0]) || shift(@_);
        my ($self, $atime, $mtime) = @_;
        CORE::utime($atime, $mtime, "$self")
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub truncate {
        ref($_[0]) || shift(@_);
        my ($self, $length) = @_;
        CORE::truncate("$self", $length // 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub unlink {
        my ($self, @args) = @_;

        if (ref($self)) {
            CORE::unlink("$self")
              ? (Sidef::Types::Bool::Bool::TRUE)
              : (Sidef::Types::Bool::Bool::FALSE);
        }
        else {
            Sidef::Types::Number::Number::_new_uint(CORE::unlink(@args));
        }
    }

    *delete = \&unlink;
    *remove = \&unlink;

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('File(' . ${Sidef::Types::String::String->new("$self")->dump} . ')');
    }

    # Path split
    *split = \&Sidef::Types::Glob::Dir::split;

};

1
