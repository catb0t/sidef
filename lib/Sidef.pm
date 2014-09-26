package Sidef {

    use 5.014;
    our $VERSION = 0.01;

    {
        my %types = (
                     bool   => {class => {'Sidef::Types::Bool::Bool'  => 1}},
                     code   => {class => {'Sidef::Types::Block::Code' => 1}},
                     hash   => {class => {'Sidef::Types::Hash::Hash'  => 1}},
                     number => {
                                class => {'Sidef::Types::Number::Number' => 1},
                                type  => 'SCALAR'
                               },
                     var_ref => {class => {'Sidef::Variable::Ref' => 1}},
                     file    => {
                              class => {'Sidef::Types::Glob::File' => 1},
                              type  => 'SCALAR'
                             },
                     dir   => {class => {'Sidef::Types::Glob::Dir'    => 1}, type => 'SCALAR'},
                     regex => {class => {'Sidef::Types::Regex::Regex' => 1}},
                     pair  => {
                              class => {'Sidef::Types::Array::Pair' => 1},
                              type  => 'ARRAY'
                             },
                     string => {
                                class => {
                                          'Sidef::Types::String::String' => 1,
                                          'Sidef::Types::Char::Char'     => 1,
                                         },
                                type => 'SCALAR'
                               },
                     array => {
                               type  => 'ARRAY',
                               class => {
                                         'Sidef::Types::Array::Array' => 1,
                                         'Sidef::Types::Char::Chars'  => 1,
                                         'Sidef::Types::Byte::Bytes'  => 1,
                                        }
                              },
                    );

        no strict 'refs';

        foreach my $type (keys %types) {
            *{__PACKAGE__ . '::' . '_is_' . $type} = sub {

                my ($self, $obj, $strict_obj, $dont_warn) = @_;

                if (exists $types{$type}{class}{ref($obj)}) {
                    return 1;
                }
                else {
                    my ($sub) = [caller(1)]->[3] =~ /^.*[^:]::(.+)$/;

                    if (!$dont_warn) {

                        my $ref_obj = [caller(0)]->[0];

                        warn sprintf(
                                     "[WARN] %sbject '%s' expected an object of type '$type', but got '%s'!\n",
                                     (
                                      $sub eq '__ANON__'
                                      ? 'O'
                                      : sprintf("The method '%s' from o", $sub)
                                     ),
                                     $ref_obj,
                                     ref($obj) || "an undefined object"
                                    );
                    }

                    if (!$strict_obj) {
                        if (    defined $obj
                            and exists $types{$type}{type}
                            and $obj->isa($types{$type}{type})) {
                            return 1;
                        }
                    }
                }

                $dont_warn ? () : (die "[ERROR] Can't continue...\n");
            };
        }

        foreach my $method (['!=', 1], ['==', 0]) {

            *{__PACKAGE__ . '::' . $method->[0]} = sub {
                my ($self, $arg) = @_;

                my $call = $method->[0];
                my $bool = $method->[1];

                if (not defined($arg)
                    and ref($self) eq 'Sidef::Types::Nil::Nil') {
                    return Sidef::Types::Bool::Bool->new(!$bool);
                }

                ref($self) ne ref($arg)
                  and return Sidef::Types::Bool::Bool->new($bool);

                if (not defined($arg)
                    or ref($self) eq 'Sidef::Types::Nil::Nil') {
                    return Sidef::Types::Bool::Bool->new(!$bool);
                }
                elsif (ref($self) eq 'Sidef::Types::Bool::Bool') {
                    return Sidef::Types::Bool::Bool->new(($$self eq $$arg) - $bool);
                }

                return Sidef::Types::Bool::Bool->new($bool);
            };
        }

        sub def_method {
            my ($self, $name, $block) = @_;

            *{ref($self) . '::' . $name} = sub {
                $block->call(@_);
            };
        }

        *define_method = \&def_method;

        sub METHODS {
            my ($self) = @_;
            Sidef::Types::Array::Array->new(
                map { Sidef::Types::String::String->new($_) }
                  sort { lc($a =~ tr/_//dr) cmp lc($b =~ tr/_//dr) or $a cmp $b } grep {
                          $_ ne '__ANON__'
                      and $_ ne 'ISA'
                      and $_ ne 'BEGIN'
                      and $_ ne 'AUTOLOAD'
                      and $_ ne 'DESTROY'
                  } keys %{ref($self) . '::'}
            );
        }

        # Smart match operator
        *{__PACKAGE__ . '::' . '~~'} = sub {
            my ($first, $second) = @_;

            my $f_type = ref($first);
            my $s_type = ref($second);

            # First is String
            if ($f_type eq 'Sidef::Types::String::String') {

                # String ~~ Array
                if ($s_type eq 'Sidef::Types::Array::Array') {
                    return $second->contains($first);
                }

                # String ~~ Hash
                if ($s_type eq 'Sidef::Types::Hash::Hash') {
                    return $second->exists($first);
                }

                # String ~~ String
                if ($s_type eq 'Sidef::Types::String::String') {
                    return $first->contains($second);
                }
            }

            # First is Array
            if ($f_type eq 'Sidef::Types::Array::Array') {

                # Array ~~ Array
                if ($s_type eq 'Sidef::Types::Array::Array') {
                    return $first->contains_all($second);
                }

                # Array ~~ Regex
                if ($s_type eq 'Sidef::Types::Regex::Regex') {
                    return $second->match($first);
                }

                # Array ~~ Hash
                if ($s_type eq 'Sidef::Types::Hash::Hash') {
                    return $second->keys->contains_any($first);
                }

                # Array ~~ Any
                return $first->contains($second);
            }

            # First is Hash
            if ($f_type eq 'Sidef::Types::Hash::Hash') {

                # Hash ~~ Array
                if ($s_type eq 'Sidef::Types::Array::Array') {
                    return $first->keys->contains_all($second);
                }

                # Hash ~~ Hash
                if ($s_type eq 'Sidef::Types::Hash::Hash') {
                    return $first->keys->contains_all($second->keys);
                }

                # Hash ~~ Any
                return $first->exists($second);
            }

            # First is Regex
            if ($f_type eq 'Sidef::Types::Regex::Regex') {

                # Regex ~~ Array
                if ($s_type eq 'Sidef::Types::Array::Array') {
                    return $first->match($second);
                }

                # Regex ~~ Hash
                if ($s_type eq 'Sidef::Types::Hash::Hash') {
                    return $first->match($second->keys);
                }

                # Regex ~~ Any
                return $first->match($second);
            }

            # Second is Array
            if ($s_type eq 'Sidef::Types::Array::Array') {

                # Any ~~ Array
                return $second->contains($first);
            }

            Sidef::Types::Bool::Bool->false;
        };
    }

    sub new {
        bless {}, __PACKAGE__;
    }

    sub respond_to {
        my ($self, $method) = @_;
        Sidef::Types::Bool::Bool->new($self->can($method));
    }

    *respondTo = \&respond_to;

    sub is_a {
        my ($self, $obj) = @_;
        Sidef::Types::Bool::Bool->new(ref($self) eq ref($obj));
    }

    *is_an = \&is_a;

    sub _get_indent_level {
        my $pkgname = ref(shift());

        my ($j, $i) = (1, 0);
        while (1) {
            last unless defined caller($i);
            ++$j if (scalar caller($i++) eq $pkgname);
        }

        return ($j, " " x 2);
    }

};

1;
