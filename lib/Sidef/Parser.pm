package Sidef::Parser {

    use utf8;
    use 5.014;
    use strict;
    use warnings;

    require File::Spec;

    our $DEBUG = 0;

    sub new {
        my (undef, %opts) = @_;

        my %options = (
            line          => 1,
            inc           => [File::Spec->curdir()],    # 'include' dirs (TODO: find a better way)
            class         => 'main',
            vars          => {'main' => []},
            ref_vars_refs => {'main' => []},
            EOT           => [],
            lonely_ops    => {
                           '--'  => 1,
                           '++'  => 1,
                           '??'  => 1,
                           '...' => 1,
                          },
            obj_with_do => {
                'Sidef::Types::Block::For'  => 1,
                'Sidef::Types::Bool::While' => 1,
                'Sidef::Types::Bool::If'    => 1,

                #'Sidef::Types::Block::Given' => 1,
                           },
            obj_stat => [
                         {
                          sub => sub { Sidef::Types::Nil::Nil->new },
                          re  => qr/\Gnil\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Bool::Bool->true },
                          re  => qr/\Gtrue\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Bool::Bool->false },
                          re  => qr/\Gfalse\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Block::Break->new },
                          re  => qr/\Gbreak\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Block::Next->new },
                          re  => qr/\Gnext\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Block::Continue->new },
                          re  => qr/\Gcontinue\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::FileHandle->stdin },
                          re  => qr/\GSTDIN\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::FileHandle->stdout },
                          re  => qr/\GSTDOUT\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::FileHandle->stderr },
                          re  => qr/\GSTDERR\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::Dir->new },
                          re  => qr/\GDir\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::File->new },
                          re  => qr/\GFile\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::Fcntl->new },
                          re  => qr/\GFcntl\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Array::Array->new },
                          re  => qr/\GArr(?:ay)?\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Array::Pair->new },
                          re  => qr/\GPair\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Hash::Hash->new },
                          re  => qr/\GHash\b/,
                         },
                         {
                          sub => sub { Sidef::Types::String::String->new },
                          re  => qr/\GStr(?:ing)?\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Number::Number->new },
                          re  => qr/\GNum(?:ber)?\b/,
                         },
                         {
                          sub => sub { Sidef::Math::Math->new },
                          re  => qr/\GMath\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Glob::Pipe->new },
                          re  => qr/\GPipe\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Byte::Byte->new },
                          re  => qr/\GByte\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Byte::Bytes->new },
                          re  => qr/\GBytes\b/,
                         },
                         {
                          sub => sub { Sidef::Time::Time->new('__INIT__') },
                          re  => qr/\GTime\b/,
                         },
                         {
                          sub => sub { Sidef::Sys::SIG->new },
                          re  => qr/\GSig\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Char::Char->new },
                          re  => qr/\GCha?r\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Char::Chars->new },
                          re  => qr/\GCha?rs\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Bool::Bool->new },
                          re  => qr/\GBool\b/,
                         },
                         {
                          sub => sub { Sidef::Sys::Sys->new },
                          re  => qr/\GSys\b/,
                         },
                         {
                          sub => sub { Sidef::Types::Regex::Regex->new('') },
                          re  => qr/\GRegex\b/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$., 1) },
                          re  => qr/\G\$\./,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$?, 1) },
                          re  => qr/\G\$\?/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$$, 1) },
                          re  => qr/\G\$\$/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$^T, 1) },
                          re  => qr/\G\$\^T\b/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$|, 1) },
                          re  => qr/\G\$\|/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$!, 0) },
                          re  => qr/\G\$!/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$", 0) },
                          re  => qr/\G\$"/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$\, 0) },
                          re  => qr/\G\$\\/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$/, 0) },
                          re  => qr{\G\$/},
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$;, 0) },
                          re  => qr/\G\$;/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$,, 0) },
                          re  => qr/\G\$,/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$^O, 0) },
                          re  => qr/\G\$\^O\b/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$^X, 0) },
                          re  => qr/\G\$\^PERL\b/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$0, 0) },
                          re  => qr/\G\$0\b/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$), 0) },
                          re  => qr/\G\$\)/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$(, 0) },
                          re  => qr/\G\$\(/,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$<, 1) },
                          re  => qr/\G\$</,
                         },
                         {
                          sub => sub { Sidef::Variable::Magic->new(\$>, 1) },
                          re  => qr/\G\$>/,
                         },
                        ],
            obj_keys => [    # this objects can take arguments
                {
                 sub     => sub { Sidef::Types::Bool::If->new },
                 re      => qr/\G(?=if\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Types::Bool::While->new },
                 re      => qr/\G(?=while\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Types::Block::For->new },
                 re      => qr/\G(?=for(?:each)?\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Types::Block::Return->new },
                 re      => qr/\G(?=return\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Types::Block::Try->new },
                 re      => qr/\G(?=try\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Types::Block::Given->new },
                 re      => qr/\G(?=(?:given|switch)\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Module::Require->new },
                 re      => qr/\G(?=require\b)/,
                 dynamic => 1,
                },
                {
                 sub     => sub { Sidef::Sys::Sys->new },
                 re      => qr/\G(?=(?:print(?:ln|f)?+|say)\b)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Types::Bool::Bool->new },
                 re      => qr/\G(?=!)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Types::Number::Unary->new },
                 re      => qr/\G(?=-)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Types::Number::Unary->new },
                 re      => qr/\G(?=\+)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Types::Number::Unary->new },
                 re      => qr/\G(?=~)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Types::Block::Code->new({}) },
                 re      => qr/\G(?=:)/,
                 dynamic => 0,
                },
                {
                 sub     => sub { Sidef::Variable::Ref->new() },
                 re      => qr/\G(?=[*\\&])/,
                 dynamic => 1,
                },
            ],
            keywords => {
                map { $_ => 1 }
                  qw(
                  next
                  break
                  return
                  for foreach
                  if while
                  try
                  given switch
                  continue
                  require
                  true false
                  nil
                  import
                  include
                  print printf
                  println say

                  File
                  Fcntl
                  Dir
                  Arr Array Pair
                  Hash
                  Str String
                  Num Number
                  Math
                  Pipe
                  Byte Bytes
                  Chr Char
                  Chrs Chars
                  Bool
                  Sys
                  Sig
                  Regex
                  Time

                  my
                  var
                  const
                  func
                  class
                  static
                  define

                  DATA
                  ARGV
                  ENV

                  STDIN
                  STDOUT
                  STDERR

                  __FUNC__
                  __CLASS__
                  __BLOCK__
                  __FILE__
                  __LINE__
                  __END__
                  __DATA__
                  __CLASS_NAME__

                  __USE_BIGNUM__
                  __USE_RATNUM__
                  __USE_INTNUM__
                  __USE_FASTNUM__

                  __RESET_LINE_COUNTER__

                  )
            },
            re => {
                match_flags => qr{[msixpogcdual]+},
                var_name    => qr/[[:alpha:]_]\w*(?>::[[:alpha:]_]\w*)*/,
                operators   => do {
                    local $" = q{|};

                    # The order matters! (in a way)
                    my @operators = map { quotemeta } qw(

                      ===
                      ||= ||
                      &&= &&

                      <?=
                      >?=
                      <=?=
                      >=?=
                      ^^?=
                      $$?=

                      ?<==
                      ?<=
                      ?>==
                      ?>=
                      ?^^=
                      ?$$=

                      %%
                      <=>
                      <<= >>=
                      << >>
                      |= |
                      &= &
                      == =~
                      := =
                      ^^ $$
                      <= ≤ >= ≥ < >
                      ++ --
                      += +
                      -= -
                      /= / ÷= ÷
                      **= **
                      %= %
                      ^= ^
                      *= *
                      ...
                      != ≠ ..
                      \\\\
                      ?:
                      ?? ?
                      ! \\
                      : »
                      ~
                      );

                    qr{(@operators)};
                },
            },
            %opts,
                      );

        $options{ref_vars} = $options{vars};
        bless \%options, __PACKAGE__;
    }

    sub fatal_error {
        my ($self, %opt) = @_;

        my $index = index($opt{code}, "\n", $opt{pos});
        $index += ($index == -1) ? (length($opt{code}) + 1) : -$opt{pos};

        my $rindex = rindex($opt{code}, "\n", $opt{pos});
        $rindex += 1;

        my $start = $rindex;
        my $point = $opt{pos} - $start;
        my $len   = $point + $index;

        if ($len > 78) {
            if ($point - $start > 60) {
                $start = ($point - 60);
                $point = $point - $start + $rindex;
                $len   = ($opt{pos} + $index - $start);
            }
            $len = 78 if $len > 78;
        }

        my @lines = (
                     "HAHA! That's really funny! You got me!",
                     "I thought that... Oh, you got me!",
                     "LOL! I expected... Oh, my! This is funny!",
                     "Oh, oh... Wait a second! Did you mean...? Damn!",
                     "You're emberesing me! That's not funny!",
                    );

        my $error =
            "$0: "
          . $lines[rand @lines] . "\n"
          . ($self->{script_name} // '-') . ':'
          . $self->{line}
          . ": syntax error, "
          . join(', ', grep { defined } $opt{error}, $opt{expected}) . "\n"
          . substr($opt{code}, $start, $len) . "\n";

        die $error, ' ' x ($point), '^', "\n";
    }

    sub find_var {
        my ($self, $var_name, $class) = @_;

        foreach my $var (@{$self->{vars}{$class}}) {
            next if ref $var eq 'ARRAY';
            return ($var, 1) if $var->{name} eq $var_name;
        }

        foreach my $var (@{$self->{ref_vars_refs}{$class}}) {
            next if ref $var eq 'ARRAY';
            return ($var, 0) if $var->{name} eq $var_name;
        }

        return;
    }

    sub get_name_and_class {
        my ($self, $var_name) = @_;

        my $rindex = rindex($var_name, '::');
        $rindex != -1
          ? (substr($var_name, $rindex + 2), substr($var_name, 0, $rindex))
          : ($var_name, $self->{class});
    }

    {

        # Reference: http://en.wikipedia.org/wiki/International_variation_in_quotation_marks
        my %pairs = qw~
          ( )
          [ ]
          { }
          < >
          « »
          » «
          ‹ ›
          › ‹
          「 」
          『 』
          „ ”
          “ ”
          ‘ ’
          ‚ ’
          ~;

        sub get_quoted_words {
            my ($self, %opt) = @_;

            my ($string, $pos) = $self->get_quoted_string(code => $opt{code});
            if ($string =~ /\G/gc && (my ($pos) = $self->parse_whitespace(code => $string))[0]) {
                pos($string) += $pos;
            }

            my @words;
            while ($string =~ /\G((?>[^\s\\]+|\\.)++)/gcs) {
                push @words, $1 =~ s{\\#}{#}gr;

                if ((my ($pos) = $self->parse_whitespace(code => substr($string, pos($string))))[0]) {
                    pos($string) += $pos;
                    next;
                }
            }

            return (\@words, $pos);
        }

        sub get_quoted_string {
            my ($self, %opt) = @_;

            for ($opt{code}) {

                if (/\G/gc && /\G(?=\s)/ && (my ($pos) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                    pos($_) += $pos;
                }

                my $delim;
                if (/\G(.)/gc) {
                    $delim = $1;
                    if ($delim eq '\\' && /\G(.*?)\\/gsc) {
                        return $1, pos;
                    }
                }
                else {
                    $self->fatal_error(
                                       error => qq{can't find the beginning of a string quote delimitator},
                                       code  => $_,
                                       pos   => pos($_),
                                      );
                }

                my $re_delim = quotemeta(exists($pairs{$delim}) ? ($delim . $pairs{$delim}) : $delim);

                my $string = '';
                while (/\G([^$re_delim\\]+)/gc || /\G\\([$re_delim])/gc || /\G(\\.)/gcs) {
                    $string .= $1;
                }

                if (exists $pairs{$delim}) {
                    while (/\G(?=\Q$delim\E)/) {

                        $string .= $delim;
                        my ($str, $pos) = $self->get_quoted_string(code => substr($_, pos));
                        pos($_) += $pos;
                        $string .= $str . $pairs{$delim};

                        while (/\G([^$re_delim\\]+)/gc || /\G\\([$re_delim])/gc || /\G(\\.)/gcs) {
                            $string .= $1;
                        }
                    }
                }

                my $end_delim = $pairs{$delim} // $delim;
                if (not /\G\Q$end_delim\E/gc) {
                    $self->fatal_error(
                                       error => sprintf(qq{can't find the quoted string terminator "%s"}, $end_delim),
                                       code  => $_,
                                       pos   => pos($_)
                                      );
                }

                return $string, pos;
            }
        }
    }

    sub get_method_name {
        my ($self, %opt) = @_;

        for ($opt{code}) {

            if (/\G/gc && (my ($pos, $end) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                pos($_) += $pos;
                $end && return (undef, pos);
            }

            # Alpha-numeric method name
            if (/\G($self->{re}{var_name} [!:?]?)/gxoc) {
                return $1, 0, pos;
            }

            # Operator-like method name
            if (m{\G$self->{re}{operators}}goc) {
                return $1, (exists $self->{lonely_ops}{$1} ? 0 : 1), pos;
            }

            # Method name as expression
            my ($obj, $pos) = $self->parse_expr(code => substr($_, pos));
            $obj // return undef, 0, pos($_);
            return {self => $obj}, 0, pos($_) + $pos;
        }
    }

    {
        my %var_delims = (
                          '(' => ')',
                          '|' => '|',
                         );

        sub get_init_vars {
            my ($self, %opt) = @_;

            for ($opt{code}) {

                my $end_delim;
                foreach my $key (keys %var_delims) {
                    if (/\G\Q$key\E\h*/gc) {
                        $end_delim = $var_delims{$key};
                        last;
                    }
                }

                my @vars;
                while (/\G($self->{re}{var_name})/goc) {
                    push @vars, $1;
                    if ($opt{with_vals} && defined($end_delim) && /\G=/gc) {
                        my (undef, $pos) = $self->parse_expr(code => substr($_, pos));
                        $vars[-1] .= '=' . substr($_, pos($_), $pos);
                        pos($_) += $pos;
                    }
                    defined($end_delim) && (/\G\h*,\h*/gc || last);
                }

                defined($end_delim) && /\G\h*\Q$end_delim\E/gc;
                return (\@vars, pos($_) // 0);
            }
        }

        sub parse_init_vars {
            my ($self, %opt) = @_;

            for ($opt{code}) {

                my $end_delim;
                foreach my $key (keys %var_delims) {
                    if (/\G\Q$key\E\h*/gc) {
                        $end_delim = $var_delims{$key};
                        last;
                    }
                }

                my @var_objs;
                while (/\G($self->{re}{var_name})/goc) {
                    my $name = $1;

                    if (exists $self->{keywords}{$name}) {
                        $self->fatal_error(
                                           code  => $_,
                                           pos   => (pos($_) - length($name)),
                                           error => "'$name' is either a keyword or a predefined variable!",
                                          );
                    }

                    my ($var, $code) = $self->find_var($name, $self->{class});

                    if (defined($var) && $code) {
                        warn "Redeclaration of $opt{type} '$name' in same scope, at "
                          . "$self->{script_name}, line $self->{line}\n";
                    }

                    my $value;
                    if (defined($end_delim) && /\G=/gc) {
                        my ($obj, $pos) = $self->parse_expr(code => substr($_, pos));
                        pos($_) += $pos;
                        $value = ref($obj) eq 'HASH' ? Sidef::Types::Block::Code->new($obj)->run : $obj;
                    }

                    my $obj = Sidef::Variable::Variable->new($name, $opt{type}, $value);

                    unshift @{$self->{vars}{$self->{class}}},
                      {
                        obj   => $obj,
                        name  => $name,
                        count => 0,
                        type  => $opt{type},
                        line  => $self->{line},
                      };

                    push @var_objs, $obj;
                    defined($end_delim) && (/\G\h*,\h*/gc || last);
                }

                defined($end_delim)
                  && (
                      /\G\h*\Q$end_delim\E/gc
                      || $self->fatal_error(
                                            code  => $_,
                                            pos   => (pos($_) - 1),
                                            error => "unbalanced parentheses",
                                           )
                     );

                return \@var_objs, pos;
            }
        }

    }

    sub parse_whitespace {
        my ($self, %opt) = @_;

        my $beg_line    = $self->{line};
        my $found_space = -1;
        for ($opt{code}) {
            {
                ++$found_space;

                # Whitespace
                if (/\G(?=\s)/) {

                    # Generic line
                    if (/\G\R/gc) {
                        ++$self->{line};

                        # Here-document
                        while ($#{$self->{EOT}} != -1) {
                            my ($name, $type, $obj) = @{shift @{$self->{EOT}}};

                            my $acc = '';
                            until (/\G$name(?:\R|\z)/gc) {

                                if (/\G(.*)/gc) {
                                    $acc .= "$1\n";
                                }

                                /\G\R/gc
                                  ? ++$self->{line}
                                  : die sprintf(qq{%s:%s: can't find string terminator "%s" anywhere before EOF.\n},
                                                $self->{script_name}, $beg_line, $name);
                            }

                            ++$self->{line};
                            push @{$obj->{$self->{class}}},
                              {
                                  self => $type == 0
                                ? Sidef::Types::String::String->new($acc =~ s{\\\\}{\\}gr)
                                : Sidef::Types::String::String->new($acc)->apply_escapes($self)
                              };
                        }

                        redo;
                    }

                    # Horizontal space
                    if (/\G\h+/gc) {
                        redo;
                    }

                    # Vertical space
                    if (/\G\v+/gc) {
                        redo;
                    }
                }

                # Embedded comments (http://perlcabal.org/syn/S02.html#Embedded_Comments)
                if (/\G#`(?=[[:punct:]])/gc) {
                    my (undef, $pos) = $self->get_quoted_string(code => substr($_, pos));
                    pos($_) += $pos;
                    redo;
                }

                # One-line comment
                if (/\G#.*/gc) {
                    redo;
                }

                # Multi-line C comment
                if (m{\G/\*}gc) {
                    while (1) {
                        m{\G.*?\*/}gc && last;
                        /\G.+/gc || (/\G\R/gc ? $self->{line}++ : last);
                    }
                    redo;
                }

                if ($found_space > 0) {

                    # End of a statement when two or more new lines has been found
                    if ($self->{line} - $beg_line >= 2) {
                        return pos, 1;
                    }

                    return pos;
                }

                return;
            }
        }
    }

    sub parse_expr {
        my ($self, %opt) = @_;

        for ($opt{code}) {
            {
                if (/\G/gc && (my ($pos) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                    pos($_) += $pos;
                }

                # End of an expression, or end of the script
                if (/\G;/gc || /\G\z/) {
                    return undef, pos;
                }

                # Single quoted string
                if (/\G(?=['‘‚’])/ || /\G%q\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => substr($_, pos));
                    return Sidef::Types::String::String->new($string =~ s{\\\\}{\\}gr), pos($_) + $pos;
                }

                # Double quoted string
                if (/\G(?=["“„”])/ || /\G%Q\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => (substr($_, pos)));
                    return Sidef::Types::String::String->new($string)->apply_escapes($self), pos($_) + $pos;
                }

                # Single quoted filename
                if (/\G%f\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => substr($_, pos));
                    return Sidef::Types::Glob::File->new($string =~ s{\\\\}{\\}gr), pos($_) + $pos;
                }

                # Double quoted filename
                if (/\G%F\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => (substr($_, pos)));
                    return Sidef::Types::Glob::File->new(Sidef::Types::String::String->new($string)->apply_escapes($self)),
                      pos($_) + $pos;
                }

                # Single quoted dirname
                if (/\G%d\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => substr($_, pos));
                    return Sidef::Types::Glob::Dir->new($string =~ s{\\\\}{\\}gr), pos($_) + $pos;
                }

                # Double quoted dirname
                if (/\G%D\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => (substr($_, pos)));
                    return Sidef::Types::Glob::Dir->new(Sidef::Types::String::String->new($string)->apply_escapes($self)),
                      pos($_) + $pos;
                }

                # Object as expression
                if (/\G(?=\()/) {
                    my ($obj, $pos) = $self->parse_arguments(code => substr($_, pos));
                    return $obj, pos($_) + $pos;
                }

                # Block as object
                if (/\G(?=\{)/) {
                    my ($obj, $pos) = $self->parse_block(code => substr($_, pos));
                    return $obj, pos($_) + $pos;
                }

                # Array as object
                if (/\G(?=\[)/) {

                    my $array = Sidef::Types::Array::HCArray->new();
                    my ($obj, $pos) = $self->parse_array(code => substr($_, pos));

                    if (ref $obj->{$self->{class}} eq 'ARRAY') {
                        push @{$array}, (@{$obj->{$self->{class}}});
                    }

                    #push @{$array}, {self => $obj, call => [{method => 'to_list'}]};

                    return $array, pos($_) + $pos;
                }

                # Declaration of variable types
                if (/\G(var|static|const)\b\h*/gc) {
                    my $type = $1;
                    my ($var_objs, $pos) = $self->parse_init_vars(code => substr($_, pos), type => $type);

                    $pos // $self->fatal_error(
                                               code  => $_,
                                               pos   => pos,
                                               error => "expected a variable name after the keyword '$type'!",
                                              );

                    pos($_) += $pos;
                    return Sidef::Variable::Init->new(@{$var_objs}), pos;
                }

                if (/\Gdefine\b\h*($self->{re}{var_name})\h*/gc) {
                    my $name = $1;

                    /\G=\h*/gc;    # an optional equal sign is allowed
                    my ($obj, $pos) = $self->parse_expr(code => substr($_, pos));

                    $obj // $self->fatal_error(
                                               code  => $_,
                                               pos   => pos,
                                               error => "expected an expression after the variable name '$name'!",
                                              );

                    $obj = ref($obj) eq 'HASH' ? Sidef::Types::Block::Code->new($obj)->run : $obj;

                    pos($_) += $pos;
                    unshift @{$self->{vars}{$self->{class}}},
                      {
                        obj   => $obj,
                        name  => $name,
                        count => 0,
                        type  => 'define',
                        line  => $self->{line},
                      };

                    return $obj, pos;
                }

                # Declaration of the 'my' special variable + class and function declarations
                if (   /\G(my)\h+($self->{re}{var_name})\h*/goc
                    || /\G(func|class)\b\h*($self->{re}{var_name})\h*/goc
                    || (defined($self->{current_class}) && /\G(func)\h*($self->{re}{operators})\h*/goc)
                    || /\G(func|class)\b()\h*/goc) {
                    my $type = $1;
                    my $name = $2;

                    if (exists $self->{keywords}{$name}) {
                        $self->fatal_error(
                                           code  => $_,
                                           pos   => (pos($_) - length($name)),
                                           error => "'$name' is either a keyword or a predefined variable!",
                                          );
                    }

                    my $variable =
                        $type eq 'my' ? Sidef::Variable::My->new($name)
                      : $type eq 'func' ? Sidef::Variable::Variable->new($name, $type)
                      : $type eq 'class' ? Sidef::Variable::ClassInit->__new($name)
                      : $self->fatal_error(
                                           error    => "invalid type",
                                           expected => "(developer fault)",
                                           code     => $_,
                                           pos      => pos($_),
                                          );

                    unshift @{$self->{vars}{$self->{class}}},
                      {
                        obj   => $variable,
                        name  => $name,
                        count => 0,
                        type  => $type,
                        line  => $self->{line},
                      };

                    if ($type eq 'my') {
                        return Sidef::Variable::InitMy->new($name), pos($_);
                    }

                    if ($type eq 'class') {
                        my ($var_names, $pos1) = $self->get_init_vars(code => substr($_, pos), with_vals => 0);
                        pos($_) += $pos1;

                        /\G\h*\{\h*/gc
                          || $self->fatal_error(
                                                error    => "invalid class declaration",
                                                expected => "expected: class $name(...){...}",
                                                code     => $_,
                                                pos      => pos($_)
                                               );

                        local $self->{class}         = $name;
                        local $self->{current_class} = $variable;
                        my ($obj, $pos) = $self->parse_block(code => '{' . substr($_, pos));
                        pos($_) += $pos - 1;

                        $variable->__set_value($obj, @{$var_names});
                    }

                    if ($type eq 'func') {

                        my ($var_names, $pos1) = $self->get_init_vars(code => substr($_, pos), with_vals => 1);
                        pos($_) += $pos1;

                        /\G\h*\{\h*/gc
                          || $self->fatal_error(
                                                error    => "invalid function declaration",
                                                expected => "expected: func $name(...){...}",
                                                code     => $_,
                                                pos      => pos($_)
                                               );

                        local $self->{current_function} = $variable;
                        my $args = '|' . join(',', @{$var_names}) . '|';
                        my ($obj, $pos) = $self->parse_block(code => '{' . $args . substr($_, pos));
                        pos($_) += $pos - (length($args) + 1);

                        $variable->set_value($obj);
                    }

                    return $variable, pos;
                }

                # Binary, hexdecimal and octal numbers
                if (/\G0(b[10_]*|x[0-9A-Fa-f_]*|[0-9_]+\b)/gc) {
                    my $number = "0" . ($1 =~ tr/_//dr);
                    return
                      Sidef::Types::Number::Number->new(
                                                        $number =~ /^0[0-9]/
                                                        ? Math::BigInt->from_oct($number)
                                                        : Math::BigInt->new($number)
                                                       ),
                      pos;
                }

                # Integer or float number
                if (/\G([+-]?+(?=\.?[0-9])[0-9_]*+(?:\.[0-9_]++)?(?:[Ee](?:[+-]?+[0-9_]+))?)/gc) {
                    return Sidef::Types::Number::Number->new($1 =~ tr/_//dr), pos;
                }

                # Implicit method call on special variable: _
                if (/\G\./) {
                    my ($var) = $self->find_var('_', $self->{class});

                    if (defined $var) {
                        return $var->{obj}, pos;
                    }

                    $self->fatal_error(
                                       code  => $_,
                                       pos   => pos($_) - 1,
                                       error => "attempt to use an implicit method call on the uninitialized variable: \"_\"",
                                      );
                }

                # Quoted words (%w/a b c/)
                if (/\G%(w)\b/gci || /\G(?=(«|<(?!<)))/) {
                    my ($type) = $1;

                    my $array = Sidef::Types::Array::Array->new();
                    my ($strings, $pos) = $self->get_quoted_words(code => substr($_, pos));

                    $array->push(
                        map {
                            $type eq 'w' || $type eq '<'
                              ? Sidef::Types::String::String->new($_)->unescape
                              : Sidef::Types::String::String->new($_)->apply_escapes($self)
                          } @{$strings}
                    );
                    return $array, pos($_) + $pos;
                }

                foreach my $hash_ref (@{$self->{obj_keys}}) {
                    if (/$hash_ref->{re}/) {
                        return (
                                (
                                   $hash_ref->{dynamic}
                                 ? $hash_ref->{sub}->()
                                 : ($self->{static_objects}{$hash_ref} //= $hash_ref->{sub}->())
                                ),
                                pos, 1
                               );
                    }
                }

                # Regular expression
                if (m{\G(?=/)} || /\G%r\b/gc) {
                    my ($string, $pos) = $self->get_quoted_string(code => (substr($_, pos)));
                    pos($_) += $pos;

                    return Sidef::Types::Regex::Regex->new($string, /\G($self->{re}{match_flags})/goc ? $1 : undef), pos;
                }

                # Backtick
                if (/\G(?=`)/) {
                    my ($string, $pos) = $self->get_quoted_string(code => (substr($_, pos)));

                    return Sidef::Types::Glob::Backtick->new(Sidef::Types::String::String->new($string)->apply_escapes($self)),
                      pos($_) + $pos;
                }

                foreach my $hash_ref (@{$self->{obj_stat}}) {
                    if (/$hash_ref->{re} (?!::)/gxc) {
                        return (($self->{static_objects}{$hash_ref} //= $hash_ref->{sub}->()), pos);
                    }
                }

                if (/\G__RESET_LINE_COUNTER__\b;*/gc) {
                    $self->{line} = 0;
                    redo;
                }

                if (/\G__CLASS_NAME__\b/gc) {
                    return Sidef::Types::String::String->new($self->{class}), pos;
                }

                if (/\G__FILE__\b/gc) {
                    return Sidef::Types::String::String->new($self->{script_name}), pos;
                }

                if (/\G__LINE__\b/gc) {
                    return Sidef::Types::Number::Number->new($self->{line}), pos;
                }

                if (/\G__(?:END|DATA)__\b\h*+\R?/gc) {

                    if (exists $self->{'__DATA__'}) {
                        $self->{'__DATA__'} = substr($_, pos);
                    }

                    return undef, length($_);
                }

                if (/\GDATA\b/gc) {
                    return +(
                        $self->{static_objects}{'__DATA__'} //= do {
                            open my $str_fh, '<:encoding(UTF-8)', \$self->{'__DATA__'};
                            Sidef::Types::Glob::FileHandle->new(fh   => $str_fh,
                                                                file => Sidef::Types::Nil::Nil->new);
                          }
                      ),
                      pos;
                }

                # Begining of here-document (<<"EOT", <<'EOT', <<EOT)
                if (/\G<</gc) {
                    my ($name, $type) = (undef, 1);

                    if (/\G(?=(['"]))/) {
                        $type = 0 if $1 eq q{'};
                        my ($str, $pos) = $self->get_quoted_string(code => substr($_, pos));
                        pos($_) += $pos;
                        $name = $str;
                    }
                    elsif (/\G(\S+)/gc) {
                        $name = $1;
                    }
                    else {
                        return undef, pos($_) - 2;
                    }

                    my $obj = {$self->{class} => []};
                    push @{$self->{EOT}}, [$name, $type, $obj];

                    return $obj, pos($_);
                }

                if (/\G__USE_BIGNUM__\b;*/gc) {
                    delete $INC{'Sidef/Types/Number/Number.pm'};
                    require Sidef::Types::Number::Number;
                    redo;
                }

                if (/\G__USE_FASTNUM__\b;*/gc) {
                    delete $INC{'Sidef/Types/Number/NumberFast.pm'};
                    require Sidef::Types::Number::NumberFast;
                    redo;
                }

                if (/\G__USE_INTNUM__\b;*/gc) {
                    delete $INC{'Sidef/Types/Number/NumberInt.pm'};
                    require Sidef::Types::Number::NumberInt;
                    redo;
                }

                if (/\G__USE_RATNUM__\b;*/gc) {
                    delete $INC{'Sidef/Types/Number/NumberRat.pm'};
                    require Sidef::Types::Number::NumberRat;
                    redo;
                }

                if (/\G__BLOCK__\b/gc) {
                    if (exists $self->{current_block}) {
                        return $self->{current_block}, pos;
                    }

                    $self->fatal_error(
                                       code  => $_,
                                       pos   => pos($_) - length('__BLOCK__'),
                                       error => "__BLOCK__ can't be used outside a block!",
                                      );
                }

                if (/\G__FUNC__\b/gc) {
                    if (exists $self->{current_function}) {
                        return $self->{current_function}, pos;
                    }

                    $self->fatal_error(
                                       code  => $_,
                                       pos   => pos($_) - length('__FUNC__'),
                                       error => "__FUNC__ can't be used outside a function!",
                                      );
                }

                if (/\G__CLASS__\b/gc) {
                    if (exists $self->{current_class}) {
                        return $self->{current_class}, pos;
                    }

                    $self->fatal_error(
                                       code  => $_,
                                       pos   => pos($_) - length('__CLASS__'),
                                       error => "__CLASS__ can't be used outside a function!",
                                      );
                }

                if (
                    /\G((?>ENV|ARGV))\b/gc && do {
                        ref(($self->find_var($1, $self->{class}))[0]) ? do { pos($_) -= length($1); 0 } : 1;
                    }
                  ) {
                    my $name = $1;
                    my $type = 'var';

                    my $variable = Sidef::Variable::Variable->new($name, $type);

                    unshift @{$self->{vars}{$self->{class}}},
                      {
                        obj   => $variable,
                        name  => $name,
                        count => 1,
                        type  => $type,
                        line  => $self->{line},
                      };

                    if ($name eq 'ARGV') {
                        require Encode;
                        my $array =
                          Sidef::Types::Array::Array->new(map { Sidef::Types::String::String->new(Encode::decode_utf8($_)) }
                                                          @ARGV);

                        $variable->set_value($array);
                    }
                    elsif ($name eq 'ENV') {
                        require Encode;
                        my $hash =
                          Sidef::Types::Hash::Hash->new(map { Sidef::Types::String::String->new(Encode::decode_utf8($_)) }
                                                        %ENV);

                        $variable->set_value($hash);
                    }

                    return $variable, pos;
                }

                # Variable call
                if (/\G($self->{re}{var_name})/goc) {

                    my $var_name = $1;

                    #my ($name, $class) = $self->get_name_and_class($var_name);
                    #my $name = $var_name;
                    #my $class = $self->{class};

                    ##if (not exists $self->{ref_vars_refs}{$class} or not exists $self->{ref_vars}{$class} ) {
                    #   say $class;
                    #   $name = $var_name;
                    #   $class = $self->{class};
                    #}

                    my $name  = $var_name;
                    my $class = $self->{class};

                    my ($var, $code) = $self->find_var($name, $class);

                    #say $class;

                    if (ref $var) {
                        $var->{count}++;
                        return $var->{obj}, pos;
                    }
                    elsif (/\G(?=\h*(?:=>|:(?!=)))/) {
                        return Sidef::Types::String::String->new($var_name), pos;
                    }
                    elsif (/\G(?=\h*:?=(?![=~>]))/) {
                        unshift @{$self->{vars}{$class}},
                          {
                            obj   => Sidef::Variable::My->new($name),
                            name  => $name,
                            count => 0,
                            type  => 'my',
                            line  => $self->{line},
                          };

                        return Sidef::Variable::InitMy->new($name), pos($_) - length($name);
                    }

                    $self->fatal_error(
                                       code  => $_,
                                       pos   => (pos($_) - length($name)),
                                       error => "attempt to use an uninitialized variable <$1>",
                                      );
                }

                if (/\G\$/gc) {
                    redo;
                }

                return undef, pos($_);

                $self->fatal_error(
                                   code  => $_,
                                   pos   => pos($_),
                                   error => "unexpected char: " . substr($_, pos($_), 1),
                                  );

                #warn "$self->{script_name}:$self->{line}: unexpected char: " . substr($_, pos($_), 1) . "\n";
                #return undef, pos($_) + 1;
            }
        }
    }

    sub parse_arguments {
        my ($self, %opt) = @_;

        for ($opt{code}) {
            if (/\G\(/gc) {

                $self->{parentheses}++;
                my ($obj, $pos) = $self->parse_script(code => substr($_, pos));

                $pos // $self->fatal_error(
                                           code  => $_,
                                           pos   => (pos($_) - 1),
                                           error => "unbalanced parentheses",
                                          );

                return $obj, pos($_) + $pos;
            }
        }
    }

    sub parse_array {
        my ($self, %opt) = @_;

        for ($opt{code}) {
            if (/\G\[/gc) {

                $self->{right_brackets}++;
                my ($obj, $pos) = $self->parse_script(code => substr($_, pos));

                $pos // $self->fatal_error(
                                           code  => $_,
                                           pos   => (pos($_) - 1),
                                           error => "unbalanced right brackets",
                                          );

                return $obj, pos($_) + $pos;
            }
        }
    }

    sub parse_block {
        my ($self, %opt) = @_;

        for ($opt{code}) {
            if (/\G\{/gc) {

                $self->{curly_brackets}++;

                my $ref = $self->{vars}{$self->{class}} //= [];
                my $count = scalar(@{$self->{vars}{$self->{class}}});

                unshift @{$self->{ref_vars_refs}{$self->{class}}}, @{$ref};
                unshift @{$self->{vars}{$self->{class}}}, [];

                $self->{vars}{$self->{class}} = $self->{vars}{$self->{class}}[0];

                my $block = Sidef::Types::Block::Code->new({});
                local $self->{current_block} = $block;

                if ((my ($pos) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                    pos($_) += $pos;
                }

                my $var_objs = [];
                if (/\G(?=\|)/) {
                    my ($vars, $pos) = $self->parse_init_vars(code => substr($_, pos), type => 'var');
                    pos($_) += $pos;
                    $var_objs = $vars;
                }

                {    # special '_' variable
                    state $name = '_';
                    state $type = 'var';

                    my $var_obj = Sidef::Variable::Variable->new($name, $type);
                    push @{$var_objs}, $var_obj;
                    unshift @{$self->{vars}{$self->{class}}},
                      {
                        obj   => $var_obj,
                        name  => $name,
                        count => 0,
                        type  => $type,
                        line  => $self->{line},
                      };
                }

                my ($obj, $pos) = $self->parse_script(code => substr($_, pos));
                $pos // $self->fatal_error(
                                           code  => $_,
                                           pos   => (pos($_) - 1),
                                           error => "unbalanced curly brackets",
                                          );

                $block->{vars} = [map  { $_->{obj} }
                                  grep { ref($_) eq 'HASH' } @{$self->{vars}{$self->{class}}}
                                 ];

                $block->{init_vars} = [map { Sidef::Variable::Init->new($_) } @{$var_objs}];

                $block->{code} = $obj;
                splice @{$self->{ref_vars_refs}{$self->{class}}}, 0, $count;
                $self->{vars}{$self->{class}} = $ref;

                return $block, pos($_) + $pos;
            }
        }
    }

    sub parse_methods {
        my ($self, %opt) = @_;

        my @methods;
        for ($opt{code}) {

            pos($_) = 0;
            {
                if ((/\G(?![-=]>)/ && /\G(?=$self->{re}{operators})/) || /\G\./goc) {
                    my ($method, $req_arg, $pos) = $self->get_method_name(code => substr($_, pos));

                    if (defined($method)) {
                        pos($_) += $pos;

                        if (/\G\h*(?=[({])/gc || $req_arg) {
                            my ($arg, $pos) =
                                /\G(?=\()/ ? $self->parse_arguments(code => substr($_, pos))
                              : $req_arg ? $self->parse_obj(code => substr($_, pos))
                              : /\G(?=\{)/ ? $self->parse_block(code => substr($_, pos))
                              :              die "[PARSING ERROR] Something wrong in the if condition!";

                            if (defined $arg) {
                                pos($_) += $pos;
                                push @methods, {method => $method, arg => [$arg]};
                            }
                            else {
                                $self->fatal_error(
                                                   code  => $_,
                                                   pos   => pos($_) - 1,
                                                   error => "operator '$method' requires a right-side argument",
                                                  );
                            }
                        }
                        else {
                            push @methods, {method => $method};
                        }

                        redo;
                    }
                }
            }

            return \@methods, pos;
        }
    }

    sub parse_obj {
        my ($self, %opt) = @_;

        my %struct;
        for ($opt{code}) {
            pos($_) = 0;

            my ($obj, $pos, $obj_key) = $self->parse_expr(code => substr($_, pos));
            pos($_) += $pos;

            # This object can't take any method!
            if (ref $obj eq 'Sidef::Variable::InitMy') {
                return $obj, pos;
            }

            if (
                   (ref($obj) eq 'Sidef::Variable::Variable' and $obj->{type} eq 'func')
                || (ref($obj) eq 'Sidef::Variable::ClassInit')
                || (ref($obj) eq 'Sidef::Types::Block::Code')

                and /\G\h*(?=\()/gc
              ) {
                my ($arg, $pos) = $self->parse_arguments(code => substr($_, pos));
                pos($_) += $pos;
                $obj = {
                        $self->{class} => [
                              {
                               self => $obj,
                               call => [{method => ref($obj) eq 'Sidef::Variable::ClassInit' ? 'init' : 'call', arg => [$arg]}]
                              }
                        ]
                       };
            }

            if (defined $obj) {
                push @{$struct{$self->{class}}}, {self => $obj};

                if ($obj_key) {
                    my ($method, $req_arg, $pos) = $self->get_method_name(code => substr($_, pos));
                    pos($_) += $pos;

                    if (defined $method) {
                        my ($arg_obj, $pos) =
                          /\G\h*(?=\()/gc
                          ? ($self->parse_arguments(code => substr($_, pos)))
                          : ($self->parse_obj(code => substr($_, pos)));
                        pos($_) += $pos;

                        if (defined $arg_obj) {
                            push @{$struct{$self->{class}}[-1]{call}}, {method => $method, arg => [$arg_obj]};
                        }
                    }
                    else {
                        die "[PARSER ERROR] The same object needs to be parsed again as a method for itself!";
                    }
                }

                while (/\G(?=\[)/) {
                    my ($ind, $pos) = $self->parse_expr(code => substr($_, pos));
                    pos($_) += $pos;
                    push @{$struct{$self->{class}}[-1]{ind}}, $ind;
                }

                my @methods;
                {

                    if (/\G(?=\.$self->{re}{var_name})/o) {
                        my ($methods, $pos) = $self->parse_methods(code => substr($_, pos));
                        pos($_) += $pos;
                        push @{$struct{$self->{class}}[-1]{call}}, @{$methods};
                    }

                    if (/\G(?!\h*[=-]>)/ && /\G(?=$self->{re}{operators})/o) {
                        my ($method, $req_arg, $pos) = $self->get_method_name(code => substr($_, pos));
                        pos($_) += $pos;

                        if ($req_arg) {
                            $struct{$self->{class}}[-1]{self} = {
                                                                 $self->{class} => [
                                                                          {
                                                                           self => $struct{$self->{class}}[-1]{self},
                                                                           exists($struct{$self->{class}}[-1]{call})
                                                                           ? (call => delete $struct{$self->{class}}[-1]{call})
                                                                           : (),
                                                                           exists($struct{$self->{class}}[-1]{ind})
                                                                           ? (ind => delete $struct{$self->{class}}[-1]{ind})
                                                                           : (),
                                                                          }
                                                                 ]
                                                                };

                            my ($arg, $pos) =
                              /\G\h*(?=\()/gc
                              ? ($self->parse_arguments(code => substr($_, pos)))
                              : ($self->parse_obj(code => substr($_, pos)));
                            pos($_) += $pos;

                            if (defined $arg) {
                                my ($methods, $pos) = $self->parse_methods(code => substr($_, pos));
                                pos($_) += $pos;

                                if (ref $arg ne 'HASH') {
                                    $arg = {$self->{class} => [{self => $arg}]};
                                }

                                if (@{$methods}) {
                                    push @{$arg->{$self->{class}}[-1]{call}}, @{$methods};
                                }
                            }
                            else {
                                $self->fatal_error(
                                                   code  => $_,
                                                   pos   => pos($_) - 1,
                                                   error => "operator '$method' requires a right-side argument",
                                                  );
                            }

                            push @{$struct{$self->{class}}[-1]{call}}, {method => $method, arg => [$arg]};
                        }
                        else {
                            push @{$struct{$self->{class}}[-1]{call}}, {method => $method};
                        }

                        redo;
                    }
                }
            }
            else {
                return undef, pos;
            }

            return \%struct, pos;

        }
    }

    sub parse_script {
        my ($self, %opt) = @_;

        my %struct;
        for ($opt{code}) {
            pos($_) = 0;
          MAIN: {

                if (/\G/gc && (my ($pos) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                    pos($_) += $pos;
                }

                if (/\Gimport\b\h*/gc) {

                    my ($var_names, $pos) = $self->get_init_vars(code => substr($_, pos), with_vals => 0);
                    pos($_) += $pos;

                    @{$var_names}
                      || $self->fatal_error(
                                            code  => $_,
                                            pos   => (pos($_)),
                                            error => "expected a variable-like name for importing!",
                                           );

                    foreach my $var_name (@{$var_names}) {
                        my ($name, $class) = $self->get_name_and_class($var_name);

                        if ($class eq $self->{class}) {
                            $self->fatal_error(
                                               code  => $_,
                                               pos   => pos($_),
                                               error => "can't import '${class}::${name}' inside the same class",
                                              );
                        }

                        my ($var, $code) = $self->find_var($name, $class);

                        if (not defined $var) {
                            $self->fatal_error(
                                               code  => $_,
                                               pos   => pos($_),
                                               error => "variable '${class}::${name}' hasn't been declared",
                                              );
                        }

                        $var->{count}++;

                        unshift @{$self->{vars}{$self->{class}}},
                          {
                            obj   => $var->{obj},
                            name  => $name,
                            count => 0,
                            type  => $var->{type},
                            line  => $self->{line},
                          };
                    }

                    redo;
                }

                if (/\Ginclude\b\h*/gc) {

                    my ($var_names, $pos) = $self->get_init_vars(code => substr($_, pos), with_vals => 0);
                    pos($_) += $pos;

                    @{$var_names}
                      || $self->fatal_error(
                                            code  => $_,
                                            pos   => (pos($_)),
                                            error => "expected a variable-like `Module::Name'!",
                                           );

                    foreach my $var_name (@{$var_names}) {
                        my @path = split(/::/, $var_name);
                        my $mod_path = File::Spec->catfile(@path[0 .. $#path - 1], $path[-1] . '.sm');

                        my ($full_path, $found_module);
                        foreach my $inc_dir (@{$self->{inc}}) {
                            if (-e ($full_path = File::Spec->catfile($inc_dir, $mod_path)) and -f _ and -r _) {
                                $found_module = 1;
                                last;
                            }
                        }

                        $found_module // $self->fatal_error(
                                                            code  => $_,
                                                            pos   => pos($_),
                                                            error => "can't find the module '${mod_path}' anywhere in ['"
                                                              . join("', '", @{$self->{inc}}) . "']",
                                                           );

                        open(my $fh, '<:encoding(UTF-8)', $full_path)
                          || $self->fatal_error(
                                                code  => $_,
                                                pos   => pos($_),
                                                error => "can't open the file '$full_path': $!"
                                               );

                        my $content = do { local $/; <$fh> };
                        close $fh;

                        my $parser = __PACKAGE__->new(script_name => $full_path);
                        my $struct = $parser->parse_script(code => $content);

                        foreach my $class (keys %{$struct}) {
                            $struct{$class} = $struct->{$class};
                            $self->{ref_vars}{$class} = $parser->{ref_vars}{$class};
                        }
                    }

                    redo;
                }

                if (/\G;+/gc) {
                    redo;
                }

                my ($obj, $pos) = $self->parse_obj(code => substr($_, pos));
                pos($_) += $pos;

                my $ref_obj = ref($obj) eq 'HASH' ? ref($obj->{$self->{class}}[-1]{self}) : ref($obj);

                if (defined $obj) {
                    push @{$struct{$self->{class}}}, {self => $obj};

                    if (ref $obj eq 'Sidef::Variable::InitMy') {
                        /\G\h*;+/gc;
                        redo;
                    }

                    {
                        if ((my ($pos, $end) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                            pos($_) += $pos;
                            $end and redo MAIN;
                        }

                        if (/\G(?:=>|,)/gc) {
                            redo MAIN;
                        }

                        my $is_operator = /\G(?!->)/ && /\G(?=$self->{re}{operators})/o;
                        if ($is_operator || /\G(?:->|\.)\h*/gc || /\G(?=$self->{re}{var_name})/o) {

                            if ((my ($pos, $end) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                                pos($_) += $pos;
                                $end && redo MAIN;
                            }

                            my ($methods, $pos) =
                              $self->parse_methods(
                                                   code => $is_operator
                                                   ? substr($_, pos)
                                                   : ("." . substr($_, pos))
                                                  );

                            pos($_) += $pos - ($is_operator ? 0 : 1);

                            if (@{$methods}) {
                                push @{$struct{$self->{class}}[-1]{call}}, @{$methods};
                            }
                            else {
                                $self->fatal_error(
                                                   error => 'incomplete method name',
                                                   code  => $_,
                                                   pos   => pos($_) - 1,
                                                  );
                            }

                            redo;
                        }
                    }
                }

                if (/\G;+/gc) {
                    redo;
                }

                # We are at the end of the script.
                # We make some checks, and return the \%struct hash ref.
                if (/\G\z/) {

                    my $check_vars;
                    $check_vars = sub {
                        my ($hash_ref) = @_;

                        foreach my $class (grep { $_ eq 'main' } keys %{$hash_ref}) {

                            my $array_ref = $hash_ref->{$class};

                            foreach my $variable (@{$array_ref}) {
                                if (ref $variable eq 'ARRAY') {
                                    $check_vars->({$class => $variable});
                                }
                                elsif (   $variable->{count} == 0
                                       && $variable->{name} ne '_'
                                       && $variable->{type} ne 'class'
                                       && $variable->{name} ne '') {
                                    warn +(   $variable->{type} eq 'const'
                                           || $variable->{type} eq 'define' ? 'Constant' : 'Variable')
                                      . " '$variable->{name}' has been initialized, but not used again, at "
                                      . "$self->{script_name}, line $variable->{line}\n";
                                }
                                elsif ($DEBUG) {
                                    warn "Variable '$variable->{name}' is used $variable->{count} times!\n";
                                }
                            }
                        }

                    };

                    $check_vars->($self->{ref_vars});

                    return \%struct;
                }

                if (/\G\]/gc) {

                    if (--$self->{right_brackets} < 0) {
                        $self->fatal_error(
                                           error => 'unbalanced right brackets',
                                           code  => $_,
                                           pos   => pos($_) - 1,
                                          );
                    }

                    return (\%struct, pos);
                }

                if (/\G\}/gc) {

                    if (--$self->{curly_brackets} < 0) {
                        $self->fatal_error(
                                           error => 'unbalanced curly brackets',
                                           code  => $_,
                                           pos   => pos($_) - 1,
                                          );
                    }

                    return (\%struct, pos);
                }

                # The end of an argument expression
                if (/\G\)/gc) {

                    if (--$self->{parentheses} < 0) {
                        $self->fatal_error(
                                           error => 'unbalanced parentheses',
                                           code  => $_,
                                           pos   => pos($_) - 1,
                                          );
                    }

                    return (\%struct, pos);
                }

                # If the object can take a block joined with a 'do' method
                if (exists $self->{obj_with_do}{$ref_obj}) {

                    {
                        my ($arg, $pos) = $self->parse_expr(code => substr($_, pos));

                        if (defined $arg) {
                            pos($_) += $pos;
                            push @{$struct{$self->{class}}[-1]{call}}, {method => 'do', arg => [$arg]};

                            if (/\G\h*(\R\h*)?(?=$self->{re}{var_name})/goc) {

                                if (defined $1) {
                                    $self->{line}++;
                                }

                                my ($methods, $pos) = $self->parse_methods(code => "." . substr($_, pos));

                                if (@{$methods}) {
                                    pos($_) += $pos - 1;
                                    push @{$struct{$self->{class}}[-1]{call}}, @{$methods};

                                    if ((my ($pos, $end) = $self->parse_whitespace(code => substr($_, pos)))[0]) {
                                        pos($_) += $pos;
                                        $end and redo MAIN;
                                    }

                                    redo;
                                }
                            }

                            if (/\G\h*;/gc) {
                                redo MAIN;
                            }
                        }
                    }

                    redo MAIN;
                }

                $self->fatal_error(
                                   code  => $_,
                                   pos   => (pos($_)),
                                   error => "expected a method",
                                  );
            }
        }
    }
};

1
