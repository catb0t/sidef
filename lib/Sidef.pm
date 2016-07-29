package Sidef {

    use 5.014;
    our $VERSION = '2.30';

    our $SPACES      = 0;    # the current number of spaces
    our $SPACES_INCR = 4;    # the number of spaces incrementor

    our @NAMESPACES;         # will keep track of declared modules
    our %INCLUDED;           # will keep track of included modules

    our %EVALS;              # will contain info required for eval()

    use constant {
                  UPDATE_SEC   => 5 * 60 * 60,         # 5 hours
                  DELETE_SEC   => 2 * 24 * 60 * 60,    # 2 days
                  SANITIZE_SEC => 3 * 24 * 60 * 60,    # 3 days
                 };

    require List::Util;
    require File::Spec;

    use Sidef::Types::Bool::Bool;
    use Sidef::Types::Number::Number;

    sub new {
        my ($class, %opt) = @_;
        bless \%opt, $class;
    }

    sub parse_code {
        my ($self, $code) = @_;

        local %INCLUDED;
        local @NAMESPACES;

        $self->{parser} //= Sidef::Parser->new(
                                               opt         => $self->{opt},
                                               file_name   => $self->{name} // '-',
                                               script_name => $self->{name} // '-',
                                               ($self->{parser_opt} ? (%{$self->{parser_opt}}) : ()),
                                              );

        my $ast = $self->{parser}->parse_script(code => \$code);
        $self->{namespaces} = \@NAMESPACES;

        # Check for optimization
        if (defined(my $level = $self->{opt}{O})) {

            # Optimize the AST
            if ($level >= 1) {
                $ast = $self->optimize_ast($ast);
            }

            # Deparse the AST into code, then parse the code again.
            if ($level >= 2) {
                my $sidef = Sidef->new(
                                       opt        => $self->{opt},
                                       name       => $self->{name},
                                       parser_opt => $self->{parser_opt},
                                      );

                local $sidef->{opt}{O} = 1;
                return $sidef->parse_code($self->compile_ast($ast, 'Sidef'));
            }
        }

        return $ast;
    }

    sub optimize_ast {
        my ($self, $ast) = @_;
        my $optimizer = Sidef::Optimizer->new;
        scalar {$optimizer->optimize($ast)};
    }

    sub execute_code {
        my ($self, $code) = @_;
        $self->execute_perl($self->compile_code($code, 'Perl'));
    }

    sub execute_perl {
        my ($self, $code) = @_;
        local $Sidef::PARSER   = $self->{parser};
        local $Sidef::DEPARSER = $self->{Perl}{deparser};
        eval($code);
    }

    sub get_sidef_vdir {
        my ($self) = @_;

        return $self->{_sidef_vdir}
          if exists($self->{_sidef_vdir});

        $self->{_sidef_vdir} = File::Spec->catdir(
                                                  $self->{sidef_config_dir}
                                                    || $ENV{SIDEF_CONFIG_DIR}
                                                    || File::Spec->catdir(
                                                                      $ENV{XDG_CONFIG_DIR}
                                                                        || File::Spec->catdir(
                                                                          (
                                                                                $ENV{HOME}
                                                                             || $ENV{LOGDIR}
                                                                             || (
                                                                                 $^O eq 'MSWin32'
                                                                                 ? '\Local Settings\Application Data'
                                                                                 : eval { ((getpwuid($<))[7] || `echo -n ~`) }
                                                                                )
                                                                             || File::Spec->curdir()
                                                                          ),
                                                                          '.config'
                                                                        ),
                                                                      'sidef'
                                                    ),
                                                  "v$VERSION"
                                                 );

        $self->{_sidef_vdir};
    }

    sub has_dbm_driver {
        my ($self) = @_;

        if (exists($self->{_db}) or exists($self->{_gdbm})) {
            return ($self->{_db} || $self->{_gdbm});
        }

        if (eval { require DB_File; 1 }) {
            $self->{_db} = 1;
            return 1;
        }
        else {
            $self->{_db} = 0;
        }

        if (eval { require GDBM_File; 1 }) {
            $self->{_gdbm} = 1;
            return 1;
        }
        else {
            $self->{_gdbm} = 0;
        }

        return;
    }

    sub _init_db {
        my ($self, $hash, $db_file) = @_;

        if ($self->{dbm_driver} eq 'gdbm') {
            state $x = require GDBM_File;
            tie %$hash, 'GDBM_File', $db_file, &GDBM_File::GDBM_WRCREAT, 0640;
        }
        elsif ($self->{dbm_driver} eq 'bdbm') {
            state $x = require DB_File;
            state $y = require Fcntl;
            tie %$hash, 'DB_File', $db_file, &Fcntl::O_CREAT | &Fcntl::O_RDWR, 0640, $DB_File::DB_HASH;
        }
    }

    sub _init_time_db {
        my ($self, $lang) = @_;

        if (not exists $self->{$lang}{_time_hash}) {
            $self->{$lang}{_time_hash} = {};
            $self->_init_db($self->{$lang}{_time_hash}, $self->{$lang}{time_db});

            if (not exists $self->{$lang}{_time_hash}{sanitized}) {
                $self->{$lang}{_time_hash}{sanitized} = time;
            }
        }
    }

    sub _init_code_db {
        my ($self, $lang) = @_;

        if (not exists $self->{$lang}{_code_hash}) {
            $self->{$lang}{_code_hash} = {};
            $self->_init_db($self->{$lang}{_code_hash}, $self->{$lang}{code_db});
        }
    }

    sub dbm_lookup {
        my ($self, $lang, $md5) = @_;

        $self->_init_time_db($lang)
          if not exists($self->{$lang}{_time_hash});

        if (exists($self->{$lang}{_time_hash}{$md5})) {
            $self->_init_code_db($lang)
              if not exists($self->{$lang}{_code_hash});

            if (time - $self->{$lang}{_time_hash}{$md5} >= UPDATE_SEC) {
                $self->{$lang}{_time_hash}{$md5} = time;
            }

            my $compressed_code = $self->{$lang}{_code_hash}{$md5};

            state $x = require IO::Uncompress::RawInflate;
            IO::Uncompress::RawInflate::rawinflate(\$compressed_code => \my $decompressed_code)
              or die "rawinflate failed: $IO::Uncompress::RawInflate::RawInflateError";

            return Encode::decode_utf8($decompressed_code);
        }

        return;
    }

    sub dbm_store {
        my ($self, $lang, $md5, $code) = @_;

        $self->_init_code_db($lang)
          if not exists($self->{$lang}{_code_hash});

        # Sanitize the database, by removing old entries
        if (time - $self->{$lang}{_time_hash}{sanitized} >= SANITIZE_SEC) {

            $self->{$lang}{_time_hash}{sanitized} = time;

            my @delete_keys;
            while (my ($key, $value) = each %{$self->{$lang}{_time_hash}}) {
                if (time - $value >= DELETE_SEC) {
                    push @delete_keys, $key;
                }
            }

            if (@delete_keys) {
                delete @{$self->{$lang}{_time_hash}}{@delete_keys};
                delete @{$self->{$lang}{_code_hash}}{@delete_keys};
            }
        }

        state $x = require IO::Compress::RawDeflate;
        IO::Compress::RawDeflate::rawdeflate(\$code => \my $compressed_code)
          or die "rawdeflate failed: $IO::Compress::RawDeflate::RawDeflateError";

        $self->{$lang}{_time_hash}{$md5} = time;
        $self->{$lang}{_code_hash}{$md5} = $compressed_code;
    }

    sub compile_code {
        my ($self, $code, $lang) = @_;

        $lang //= 'Sidef';

        if (
            $self->{opt}{s}
            ##and length($$code) > 1024
            and (defined($self->{dbm_driver})
                 or $self->has_dbm_driver)
          ) {

            my $db_dir = ($self->{$lang}{db_dir} //= File::Spec->catdir($self->get_sidef_vdir(), $lang));

            if (not -e $db_dir) {
                require File::Path;
                File::Path::make_path($db_dir);
            }

            state $x = require Digest::MD5;
            state $y = require Encode;

            my $md5 = Digest::MD5::md5_hex(Encode::encode_utf8($code));

            $self->{dbm_driver} //= (
                                       $self->{_gdbm} ? 'gdbm'
                                     : $self->{_db}   ? 'bdbm'
                                     :                  die "unknown DBM driver"
                                    );

            $self->{$lang}{time_db} //= File::Spec->catfile($db_dir, 'Sidef_Time_' . $self->{dbm_driver} . '.db');
            $self->{$lang}{code_db} //= File::Spec->catfile($db_dir, 'Sidef_Code_' . $self->{dbm_driver} . '.db');

            if (defined(my $cached_code = $self->dbm_lookup($lang, $md5))) {
                return $cached_code;
            }

            my $evals_num = keys(%EVALS);

            local $self->{environment_name} = 'Sidef::Runtime' . $md5;
            my $deparsed = $self->compile_ast($self->parse_code($code), $lang);

            if ($lang eq 'Perl') {
                $deparsed = "package $self->{environment_name} {$deparsed}\n";
            }

            # Don't store code that contains eval()
            if (keys(%EVALS) == $evals_num) {
                $self->dbm_store($lang, $md5, Encode::encode_utf8($deparsed));
            }

            return $deparsed;
        }

        state $count = 0;
        local $self->{environment_name} = 'Sidef::Runtime' . (CORE::abs($count++) || '');

        my $deparsed = $self->compile_ast($self->parse_code($code), $lang);

        if ($lang eq 'Perl') {
            $deparsed = "package $self->{environment_name} {$deparsed}\n";
        }

        return $deparsed;
    }

    sub compile_ast {
        my ($self, $ast, $lang) = @_;

        $lang //= 'Sidef';

        my $module = "Sidef::Deparse::$lang";
        my $pm     = ($module =~ s{::}{/}gr . '.pm');

        require $pm;
        $self->{$lang}{deparser} = $module->new(
                                                opt              => $self->{opt},
                                                namespaces       => $self->{namespaces},
                                                environment_name => $self->{environment_name} // '',
                                               );

        scalar $self->{$lang}{deparser}->deparse($ast);
    }

    #
    ## Util functions
    #

    sub normalize_type {
        my ($type) = @_;

        if (index($type, 'Sidef::') == 0) {
            $type = substr($type, rindex($type, '::') + 2);
        }
        else {
            $type =~ s/^(?:_::)?main:://
              or $type =~ s/^_:://;
        }

        $type =~ s/[0-9]{8}\z//r;
    }

    sub normalize_method {
        my ($type, $method) = ($_[0] =~ /^(.*[^:])::(.*)$/);
        normalize_type($type) . ".$method";
    }

    sub jaro {
        my ($s, $t) = @_;

        my $s_len = length($s);
        my $t_len = length($t);

        my $match_distance = int(List::Util::max($s_len, $t_len) / 2) - 1;

        my @s_matches;
        my @t_matches;

        my @s = split(//, $s);
        my @t = split(//, $t);

        my $matches = 0;
        foreach my $i (0 .. $s_len - 1) {

            my $start = List::Util::max(0, $i - $match_distance);
            my $end = List::Util::min($i + $match_distance + 1, $t_len);

            foreach my $j ($start .. $end - 1) {
                $t_matches[$j] and next;
                $s[$i] eq $t[$j] or next;
                $s_matches[$i] = 1;
                $t_matches[$j] = 1;
                $matches++;
                last;
            }
        }

        return 0 if $matches == 0;

        my $k     = 0;
        my $trans = 0;

        foreach my $i (0 .. $s_len - 1) {
            $s_matches[$i] or next;
            until ($t_matches[$k]) { ++$k }
            $s[$i] eq $t[$k] or ++$trans;
            ++$k;
        }

#<<<
        (($matches / $s_len) + ($matches / $t_len)
            + (($matches - $trans / 2) / $matches)) / 3;
#>>>
    }

    sub jaro_winkler {
        my ($s, $t) = @_;

        my $distance = jaro($s, $t);

        my $prefix = 0;
        foreach my $i (0 .. List::Util::min(3, length($s), length($t))) {
            substr($s, $i, 1) eq substr($t, $i, 1) ? ++$prefix : last;
        }

        $distance + $prefix * 0.1 * (1 - $distance);
    }

    sub best_matches {
        my ($name, $set) = @_;

        my $max = 0;
        my @best;
        foreach my $elem (@$set) {
            my $dist = sprintf("%.4f", jaro_winkler($elem, $name));
            $dist >= 0.8 or next;
            if ($dist > $max) {
                $max  = $dist;
                @best = ();
            }
            push(@best, $elem) if $dist == $max;
        }

        @best;
    }

};

#
## Some UNIVERSAL magic
#

*UNIVERSAL::get_value = sub {
    ref($_[0]) eq 'Sidef::Module::OO' || ref($_[0]) eq 'Sidef::Module::Func'
      ? $_[0]->{module}
      : $_[0];
};
*UNIVERSAL::DESTROY = sub { };
*UNIVERSAL::AUTOLOAD = sub {
    my ($self, @args) = @_;

    $self = ref($self) if ref($self);

    if (index($self, 'Sidef::') == 0 and index($self, 'Sidef::Runtime') != 0) {

        eval { require $self =~ s{::}{/}rg . '.pm' };

        if ($@) {
            if (defined &main::__load_sidef_module__) {
                main::__load_sidef_module__($self);
            }
            else {
                die "[AUTOLOAD] $@";
            }
        }

        if (defined(&$AUTOLOAD)) {
            return $AUTOLOAD->($self, @args);
        }
    }

    my @caller = caller(1);
    my $from   = Sidef::normalize_method($caller[3]);
    $from = $from eq '.' ? 'main()' : "$from()";

    my $table = \%{$self . '::'};
    my @methods = grep { !ref($table->{$_}) and defined(&{$table->{$_}}) } keys(%$table);

    my $method = Sidef::normalize_method($AUTOLOAD);
    my $name = substr($method, rindex($method, '.') + 1);

    my @candidates = Sidef::best_matches($name, \@methods);

    die(  "[AUTOLOAD] Undefined method `"
        . $method . q{'}
        . " called from $from\n"
        . (@candidates ? ("[?] Did you mean: " . join("\n" . (' ' x 18), sort @candidates) . "\n") : ''));
    return;
};

1;
