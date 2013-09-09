package Sidef::Types::String::String {

    use utf8;
    use 5.014;
    use strict;
    use warnings;

    our @ISA = qw(
      Sidef
      Sidef::Convert::Convert
      );

    sub new {
        my (undef, $str) = @_;
        bless \$str, __PACKAGE__;
    }

    sub get_value {
        ${$_[0]};
    }

    sub inc {
        my ($self) = @_;
        my $copy = $$self;
        $self->new(++$copy);
    }

    sub div {
        my ($self, $num) = @_;
        $self->_is_number($num) || return;
        (my $strlen = int(length($$self) / $$num)) < 1 && return;
        Sidef::Types::Array::Array->new(map { $self->new($_) } unpack "(a$strlen)*", $$self);
    }

    sub lt {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        Sidef::Types::Bool::Bool->new($$self lt $$string);
    }

    sub gt {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        Sidef::Types::Bool::Bool->new($$self gt $$string);
    }

    sub le {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        Sidef::Types::Bool::Bool->new($$self le $$string);
    }

    sub ge {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        Sidef::Types::Bool::Bool->new($$self ge $$string);
    }

    sub subtract {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        if ((my $ind = CORE::index($$self, $$string)) != -1) {
            return $self->new(CORE::substr($$self, 0, $ind) . CORE::substr($$self, $ind + CORE::length($$string)));
        }
        $self;
    }

    sub ne {
        my ($self, $string) = @_;
        ref($self) ne ref($string) and return Sidef::Types::Bool::Bool->true;
        Sidef::Types::Bool::Bool->new($$self ne $$string);
    }

    sub match {
        my ($self, $regex, @rest) = @_;
        $self->_is_regex($regex) || return;
        $regex->matches($self, @rest);
    }

    sub to {
        my ($self, $string) = @_;
        Sidef::Types::Array::Array->new(map { $self->new($_) } $$self .. $$string);
    }

    sub cmp {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        Sidef::Types::Number::Number->new($$self cmp $$string);
    }

    sub times {
        my ($self, $num) = @_;
        $self->_is_number($num) || return;
        $self->new($$self x $$num);
    }

    *multiply = \&times;

    sub repeat {
        my ($self, $num) = @_;
        $num //= Sidef::Types::Number::Number->new(1);
        $self->times($num);
    }

    sub uc {
        my ($self) = @_;
        $self->new(CORE::uc $$self);
    }

    *toUpperCase = \&uc;

    sub equals {
        my ($self, $string) = @_;
        ref($self) ne ref($string) and return Sidef::Types::Bool::Bool->false;
        Sidef::Types::Bool::Bool->new($$self eq $$string);
    }

    *eq = \&equals;
    *is = \&equals;

    sub append {
        my ($self, $string) = @_;
        $self->_is_string($string) || return;
        $self->new($$self . $$string);
    }

    *concat = \&append;

    sub ucfirst {
        my ($self) = @_;
        $self->new(CORE::ucfirst $$self);
    }

    *tc         = \&ucfirst;
    *titleCase  = \&ucfirst;
    *title_case = \&ucfirst;

    sub lc {
        my ($self) = @_;
        $self->new(CORE::lc $$self);
    }

    *toLowerCase = \&lc;

    sub lcfirst {
        my ($self) = @_;
        $self->new(CORE::lcfirst $$self);
    }

    sub tclc {
        my ($self) = @_;
        $self->new(CORE::ucfirst(CORE::lc($$self)));
    }

    sub charAt {
        my ($self, $pos) = @_;
        $self->_is_number($pos) || return;
        Sidef::Types::Char::Char->new(CORE::substr($$self, $$pos, 1));
    }

    *char_at = \&charAt;

    sub wordcase {
        my ($self) = @_;

        my $string = $1
          if ($$self =~ /\G(\s+)/gc);

        while ($$self =~ /\G(\S++)(\s*+)/gc) {
            $string .= CORE::ucfirst(CORE::lc($1)) . $2;
        }

        $self->new($string);
    }

    *wc       = \&wordcase;
    *wordCase = \&wordcase;

    sub chop {
        my ($self) = @_;
        $self->new(CORE::substr($$self, 0, -1));
    }

    sub chomp {
        my ($self) = @_;

        if (substr($$self, -1) eq "\n") {
            return $self->chop;
        }

        $self;
    }

    sub crypt {
        my ($self, $salt) = @_;
        $self->_is_string($salt) || return;
        $self->new(crypt($$self, $$salt));
    }

    sub substr {
        my ($self, $offs, $len) = @_;

        $self->_is_number($offs) || return;

        my @str = CORE::split(//, $$self);
        my $str_len = $#str;

        $offs = $$offs;

        if (defined $len) {
            $self->_is_number($len) || return;
            $len = $$len;
        }

        $offs = 1 + $str_len + $offs if $offs < 0;
        $len = defined $len ? $len < 0 ? $str_len + $len : $offs + $len - 1 : $str_len;

        __PACKAGE__->new(CORE::join '', @str[$offs .. $len]);
    }

    *substring = \&substr;

    sub insert {
        my ($self, $string, $pos, $len) = @_;

        ($self->_is_string($string) && $self->_is_number($pos))
          || return;

        if (defined $len) {
            $self->_is_number($len) || return;
        }
        else {
            $len = Sidef::Types::Number::Number->new(0);
        }

        my $new_str = $self->new($$self);
        CORE::substr($$new_str, $$pos, $$len, $$string);
        return $new_str;
    }

    sub join {
        my ($self, $delim, @rest) = @_;
        $self->_is_string($delim) || return;
        __PACKAGE__->new(CORE::join($$delim, $$self, @rest));
    }

    sub index {
        my ($self, $substr, $pos) = @_;
        $self->_is_string($substr) || return;

        if (defined($pos)) {
            $self->_is_number($pos) || return;
        }

        Sidef::Types::Number::Number->new(
                                          defined($pos)
                                          ? CORE::index($$self, $$substr, $$pos)
                                          : CORE::index($$self, $$substr)
                                         );
    }

    *indexOf = \&index;

    sub ord {
        my ($self) = @_;
        Sidef::Types::Byte::Byte->new(CORE::ord($$self));
    }

    sub reverse {
        my ($self) = @_;
        $self->new(scalar CORE::reverse($$self));
    }

    sub say {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(CORE::say($$self));
    }

    *println = \&say;

    sub print {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(print $$self);
    }

    sub printf {
        my ($self, @arguments) = @_;
        Sidef::Types::Bool::Bool->new(printf $$self, @arguments);
    }

    sub printlnf {
        my ($self, @arguments) = @_;
        Sidef::Types::Bool::Bool->new(printf($$self . "\n", @arguments));
    }

    sub sprintf {
        my ($self, @arguments) = @_;
        __PACKAGE__->new(CORE::sprintf $$self, @arguments);
    }

    sub sprintlnf {
        my ($self, @arguments) = @_;
        __PACKAGE__->new(CORE::sprintf($$self . "\n", @arguments));
    }

    sub sub {
        my ($self, $regex, $str) = @_;

        $self->_is_string($str) || return;

        if (ref($regex) ne 'Sidef::Types::Regex::Regex') {
            if ($regex->can('quotemeta')) {
                $regex = $regex->quotemeta();
            }
        }

        $self->new($$self =~ s{$regex}{$$str}r);
    }

    *replace = \&sub;

    sub gsub {
        my ($self, $regex, $str) = @_;

        $self->_is_string($str) || return;

        if (ref($regex) ne 'Sidef::Types::Regex::Regex') {
            if ($regex->can('quotemeta')) {
                $regex = $regex->quotemeta();
            }
        }

        $self->new($$self =~ s{$regex}{$$str}gr);
    }

    *gSub     = \&gsub;
    *gReplace = \&gsub;

    sub glob {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(map { __PACKAGE__->new($_) } CORE::glob($$self));
    }

    sub quotemeta {
        my ($self) = @_;
        __PACKAGE__->new(CORE::quotemeta($$self));
    }

    sub split {
        my ($self, $sep, $size) = @_;

        $size = defined($size) && ($self->_is_number($size) || return) ? $$size : 0;

        if (ref($sep) eq '') {
            return Sidef::Types::Array::Array->new(map { __PACKAGE__->new($_) } split(' ', $$self, $size));
        }
        elsif ($self->_is_number($sep, 1, 1)) {
            return Sidef::Types::Array::Array->new(map { __PACKAGE__->new($_) } unpack "(a$$sep)*", $$self);
        }
        elsif (ref($sep) ne 'Sidef::Types::Regex::Regex') {
            if ($sep->can('quotemeta')) {
                $sep = $sep->quotemeta();
            }
        }

        Sidef::Types::Array::Array->new(map { __PACKAGE__->new($_) } split(/$sep/, $$self, $size));
    }

    sub translit {
        my ($self, $orig, $repl, $modes) = @_;
        ($self->_is_string($orig) && $self->_is_string($repl)) || return;
        $self->new(
                   eval qq{"\Q$$self\E"=~tr/} . $$orig =~ s{([/\\])}{\\$1}gr . "/" . $$repl =~
                     s{([/\\])}{\\$1}gr . "/r" . (defined($modes) ? $self->_is_string($modes) ? $$modes : return : ''));
    }

    *tr = \&translit;

    sub length {
        my ($self) = @_;
        Sidef::Types::Number::Number->new(CORE::length($$self));
    }

    *len = \&length;

    sub parse {
        my ($self, $code) = @_;

        my @warnings;
        local $SIG{__WARN__} = sub { push @warnings, __PACKAGE__->new($_[0]) };

        my $parser = Sidef::Parser->new(script_name => '/eval/');
        my $struct = eval { $parser->parse_script(code => $$self) } // {};

        if ($@) {
            if (defined($code)) {
                push @warnings, __PACKAGE__->new($@);
                $self->_is_code($code) || return;
                my $var = ($code->_get_private_var)[0]->get_var;
                $var->set_value(Sidef::Types::Array::Array->new(@warnings));
                $code->run;
            }

            return;
        }

        Sidef::Types::Block::Code->new($struct);
    }

    sub eval {
        my ($self, $code) = @_;

        my $block = $self->parse($code) // return;

        my @warnings;
        local $SIG{__WARN__} = sub { push @warnings, __PACKAGE__->new($_[0]) };

        my $result = eval { $block->run };

        if ($@) {
            if (defined($code)) {
                push @warnings, __PACKAGE__->new($@);
                $self->_is_code($code) || return;
                my $var = ($code->_get_private_var)[0]->get_var;
                $var->set_value(Sidef::Types::Array::Array->new(@warnings));
                $code->run;
            }

            return;
        }

        $result;
    }

    sub contains {
        my ($self, $string, $start_pos) = @_;
        $start_pos //= Sidef::Types::Number::Number->new(0);

        ($self->_is_number($start_pos) && $self->_is_string($string))
          || return;

        if ($$start_pos < 0) {
            $$start_pos = CORE::length($$self) + $$start_pos;
        }

        Sidef::Types::Bool::Bool->new(CORE::index($$self, $$string, $$start_pos) != -1);
    }

    sub begins_with {
        my ($self, $string) = @_;

        $self->_is_string($string)
          || return;

        CORE::length($$self) < (my $len = CORE::length($$string))
          && return Sidef::Types::Bool::Bool->false;

        CORE::substr($$self, 0, $len) eq $$string
          && return Sidef::Types::Bool::Bool->true;

        Sidef::Types::Bool::Bool->false;
    }

    *starts_with = \&begins_with;
    *startsWith  = \&begins_with;
    *beginsWith  = \&begins_with;

    sub ends_with {
        my ($self, $string) = @_;

        $self->_is_string($string)
          || return;

        CORE::length($$self) < (my $len = CORE::length($$string))
          && return Sidef::Types::Bool::Bool->false;

        CORE::substr($$self, -$len) eq $$string
          && return Sidef::Types::Bool::Bool->true;

        Sidef::Types::Bool::Bool->false;
    }

    *endsWith = \&ends_with;

    sub warn {
        my ($self) = @_;
        warn $$self;
    }

    sub die {
        my ($self) = @_;
        die $$self;
    }

    sub encode {
        my ($self, $enc) = @_;
        $self->_is_string($enc) || return;
        $self->new(Encode::encode($$enc, $$self));
    }

    sub decode {
        my ($self, $enc) = @_;
        $self->_is_string($enc) || return;
        $self->new(Encode::decode($$enc, $$self));
    }

    sub encode_utf8 {
        my ($self) = @_;
        $self->new(Encode::encode_utf8($$self));
    }

    sub decode_utf8 {
        my ($self) = @_;
        $self->new(Encode::decode_utf8($$self));
    }

    sub unescape {
        my ($self) = @_;
        ${$self} =~ s{\\(\W)}{$1}gs;
        $self;
    }

    sub apply_escapes {
        my ($self) = @_;

        state $esc = {
                      n => "\n",
                      f => "\f",
                      b => "\b",
                      e => "\e",
                      r => "\r",
                      t => "\t",
                     };

        {
            local $" = q{};
            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([@{[keys %{$esc}]}])}{$esc->{$1}}go;
            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([LU])((?>[^\\]+|\\[^E])*)(\\E|\z)}{

                $1 eq 'L' ? CORE::lc($2) : CORE::uc($2);

            }eg;

            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([lu])(.)}{

                $1 eq 'l' ? CORE::lc($2) : CORE::uc($2);

            }egs;
        }

        return $self;
    }

    sub dump {
        my ($self) = @_;
        __PACKAGE__->new(q{'} . $$self =~ s{'}{\\'}gr . q{'});
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '=~'}  = \&match;
        *{__PACKAGE__ . '::' . '*'}   = \&times;
        *{__PACKAGE__ . '::' . '+'}   = \&append;
        *{__PACKAGE__ . '::' . '++'}  = \&inc;
        *{__PACKAGE__ . '::' . '-'}   = \&subtract;
        *{__PACKAGE__ . '::' . '=='}  = \&equals;
        *{__PACKAGE__ . '::' . '!='}  = \&ne;
        *{__PACKAGE__ . '::' . '≠'} = \&ne;
        *{__PACKAGE__ . '::' . '>'}   = \&gt;
        *{__PACKAGE__ . '::' . '<'}   = \&lt;
        *{__PACKAGE__ . '::' . '>='}  = \&ge;
        *{__PACKAGE__ . '::' . '≥'} = \&ge;
        *{__PACKAGE__ . '::' . '<='}  = \&le;
        *{__PACKAGE__ . '::' . '≤'} = \&le;
        *{__PACKAGE__ . '::' . '<=>'} = \&cmp;
        *{__PACKAGE__ . '::' . '÷'}  = \&div;
        *{__PACKAGE__ . '::' . '/'}   = \&div;
        *{__PACKAGE__ . '::' . '..'}  = \&to;
        *{__PACKAGE__ . '::' . '^^'}  = \&begins_with;
        *{__PACKAGE__ . '::' . '$$'}  = \&ends_with;

        *{__PACKAGE__ . '::' . '<<'} = sub {
            my ($self, $i) = @_;

            $self->_is_number($i) || return;

            my $len = CORE::length($$self);
            $i = $$i > $len ? $len : $$i;
            $self->new(CORE::substr($$self, $i));
        };

        *{__PACKAGE__ . '::' . '>>'} = sub {
            my ($self, $i) = @_;
            $self->_is_number($i) || return;
            $self->new(CORE::substr($$self, 0, -$$i));
        };
    }
}
