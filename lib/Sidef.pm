package Sidef {

    use 5.014;
    our $VERSION = 0.07;

    our $SPACES      = 0;    # the current number of spaces
    our $SPACES_INCR = 4;    # the number of spaces incrementor

    {
        my %types = (
                     bool   => {class => {'Sidef::Types::Bool::Bool'  => 1}},
                     code   => {class => {'Sidef::Types::Block::Code' => 1}},
                     hash   => {class => {'Sidef::Types::Hash::Hash'  => 1}},
                     number => {
                                class => {
                                          'Sidef::Types::Number::Number'  => 1,
                                          'Sidef::Types::Number::Complex' => 1,
                                          'Sidef::Types::Byte::Byte'      => 1,
                                         },
                                type => 'SCALAR',
                               },
                     var_ref => {class => {'Sidef::Variable::Ref' => 1}},
                     file    => {
                              class => {'Sidef::Types::Glob::File' => 1},
                              type  => 'SCALAR',
                             },
                     fh  => {class => {'Sidef::Types::Glob::FileHandle' => 1}},
                     dir => {
                             class => {'Sidef::Types::Glob::Dir' => 1},
                             type  => 'SCALAR',
                            },
                     regex => {class => {'Sidef::Types::Regex::Regex' => 1}},
                     pair  => {
                              class => {'Sidef::Types::Array::Pair' => 1},
                              type  => 'ARRAY',
                             },
                     string => {
                                class => {
                                          'Sidef::Types::String::String' => 1,
                                          'Sidef::Types::Char::Char'     => 1,
                                         },
                                type => 'SCALAR',
                               },
                     array => {
                               class => {
                                         'Sidef::Types::Array::Array' => 1,
                                         'Sidef::Types::Array::Range' => 1,
                                         'Sidef::Types::Char::Chars'  => 1,
                                         'Sidef::Types::Byte::Bytes'  => 1,
                                        },
                               type => 'ARRAY',
                              },
                    );

        no strict 'refs';

        foreach my $type (keys %types) {
            *{__PACKAGE__ . '::' . '_is_' . $type} = sub {
                exists($types{$type}{class}{ref($_[1])}) ? 1 : 0;
            };
        }

        foreach my $method (['!=', 1], ['==', 0]) {

            *{__PACKAGE__ . '::' . $method->[0]} = sub {
                my ($self, $arg) = @_;

                if (not defined($arg)
                    and ref($self) eq 'Sidef::Types::Nil::Nil') {
                    return Sidef::Types::Bool::Bool->new(!$method->[1]);
                }

                ref($self) ne ref($arg)
                  and return Sidef::Types::Bool::Bool->new($method->[1]);

                state $x = require Scalar::Util;
                if (Scalar::Util::reftype($self) eq 'SCALAR') {
                    return Sidef::Types::Bool::Bool->new(
                         (defined($$self) ? (defined($$arg) ? $$self eq $$arg : 0) : (defined($$arg) ? 0 : 1)) - $method->[1]);
                }

                return Sidef::Types::Bool::Bool->new($method->[1]);
            };
        }

        sub def_method {
            my ($self, $name, $block) = @_;
            *{ref($self) . '::' . $name} = sub {
                $block->call(@_);
            };
            $self;
        }

        *__add_method__ = \&def_method;

        sub method {
            my ($self, $method, @args) = @_;
            Sidef::Variable::LazyMethod->new(obj => $self, method => $method, args => \@args);
        }

        sub METHODS {
            my ($self) = @_;

            my %alias;
            my %methods;
            my $ref = ref($self);
            foreach my $method (grep { $_ !~ /^[(_]/ and defined(&{$ref . '::' . $_}) } keys %{$ref . '::'}) {
                $methods{$method} = ($alias{\&{$ref . '::' . $method}} //=
                                     Sidef::Variable::LazyMethod->new(obj => $self, method => \&{$ref . '::' . $method}));
            }

            Sidef::Types::Hash::Hash->new(%methods);
        }
    }

    sub new {
        bless {}, __PACKAGE__;
    }

    sub super_join {
        my ($self, @args) = @_;
        $self->new(
            CORE::join(
                '',
                map {
                    eval { ${ref($_) ne 'Sidef::Types::String::String' ? $_->to_s : $_} }
                      // $_
                  } @args
            )
        );
    }

    sub respond_to {
        my ($self, $method) = @_;
        Sidef::Types::Bool::Bool->new($self->can($method));
    }

    sub is_a {
        my ($self, $obj) = @_;
        Sidef::Types::Bool::Bool->new(ref($self) eq ref($obj));
    }

    *is_an = \&is_a;

};

#
## Some UNIVERSAL magic
#

*UNIVERSAL::get_value = sub { $_[0] };
*UNIVERSAL::DESTROY   = sub { };
*UNIVERSAL::AUTOLOAD  = sub {
    my ($self, @args) = @_;

    $self = ref($self) if ref($self);
    $self =~ /^Sidef::/ or return;
    eval { require $self =~ s{::}{/}rg . '.pm' };

    if ($@) {
        if (defined &main::load_module) {
            main::load_module($self);
        }
        else {
            die "[AUTOLOAD] $@";
        }
    }

    my $func = \&{$AUTOLOAD};
    if (defined(&$func)) {
        return $func->($self, @args);
    }

    die "[AUTOLOAD] Undefined function: $AUTOLOAD";
    return;
};

1;
