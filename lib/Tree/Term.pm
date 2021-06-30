#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Create a parse tree from an array of terms representing an expression.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2021
#-------------------------------------------------------------------------------
package Tree::term;
use v5.26;
our $VERSION = 20210629;                                                        # Version
use warnings FATAL => qw(all);
use strict;
use Carp qw(confess cluck);
use Data::Dump qw(dump ddx pp);
use Data::Table::Text qw(:all);
use Test::More qw(no_plan);
use feature qw(say state current_sub);

my $log = q(/home/phil/perl/cpan/TreeTerm/lib/Tree/zzz.txt);                    # Log file

sub new($@)                                                                     # New term
 {my ($operator, @operands) = @_;                                               # Parameters
  my $t = genHash(__PACKAGE__,                                                  # Term
     operands => @operands ? [@operands] : undef,                               # Operands
     operator => $operator,                                                     # Operator
     up       => undef,                                                         # Parent term if any
   );
  $_->up = $t for grep {ref $_} @operands;                                      # Link to parent if possible

  $t
 }

sub depth($)                                                                    # Depth of a term in an expression
 {my ($e) = @_;                                                                 # Term
  my $d = 0;
  for(; $e; $e = $e->up) {++$d}
  $d
 }

sub listTerms($)                                                                # List the terms in an expression in post order
 {my ($e) = @_;                                                                 # Root term
  my @t;                                                                        # Terms

  sub                                                                           # Recurse through terms
   {my ($e) = @_;                                                               # Term
    my $o = $e->operands;
    return unless $e;                                                           # Operator
    if (my @o = $o ? grep {ref $_} @$o : ())                                    # Operands
     {my ($p, @p) = @o;
      __SUB__->($p);                                                            # First operand
      push @t, $e;                                                              # Operator
      __SUB__->($_) for @p;                                                     # Second and subsequent operands
     }
    else                                                                        # No operands
     {push @t, $e;                                                              # Operator
     }
   } ->($e);
  @t
 }

sub flat($@)                                                                    # Print the terms in the expression as a tree from left right to make it easier to visualize the structure of the tree.
 {my ($e, @title) = @_;                                                         # Root term, optional title
  my @t = $e->listTerms;                                                        # Terms in expression in post order
  my @s;                                                                        # Print

  my sub align                                                                  # Align the ends of the lines
   {my $L = 0;                                                                  # Longest line
    for my $s(@s)
     {my $l = length $s; $L = $l if $l > $L;
     }

    for my $i(keys @s)                                                          # Pad to longest
     {my $s = $s[$i] =~ s/\s+\Z//rs;
      my $l = length($s);
      if ($l < $L)
       {my $p = ' ' x ($L - $l);
        $s[$i] = $s . $p;
       }
     }
   };

  for my $t(@t)                                                                 # Initialize output rectangle
   {$s[$_] //= '' for 0..$t->depth;
   }

  for my $t(@t)                                                                 # Traverse tree
   {my $d = $t->depth;
    my $p = $t->operator;                                                       # Operator

    align if $p =~ m(\A(a|d|s));                                                # Shift over for some components

    $s[$d] .= " $p";                                                            # Describe operator or operand
    align unless $p =~ m(\A(p|q|v));                                            # Vertical for some components
   }

  shift @s while @s and $s[ 0] =~ m(\A\s*\Z)s;                                  # Remove leading blank lines

  for my $i(keys @s)                                                            # Clean up trailing blanks so that tests are not affected by spurious white space mismatches
   {$s[$i] =~ s/\s+\n/\n/gs;
    $s[$i] =~ s/\s+\Z//gs;
   }

  unshift @s, join(' ', @title) if @title;                                      # Add title
  join "\n", @s, '';
 }

sub parse(@)                                                                    # Parse an expression
 {my (@e) = @_;                                                                 # Expression to parse

  my @s;                                                                        # Stack

  my sub term()                                                                 # Convert the longest possible expression on top of the stack into a term
   {my $n = scalar(@s);
#   lll "TTTT $n \n", dump([@s]);

    my sub test($*)                                                             # Check the type of an item in the stack
     {my ($item, $type) = @_;                                                   # Item to test, expected type of item
      return index($type, 't') > -1 if ref $item;                               # Term
      index($type, substr($item, 0, 1)) > -1                                    # Something other than a term defines its type by its first letter
     };

    if (@s >= 3)                                                                # Go for term dyad term
     {my ($r, $d, $l) = reverse @s;
      if (test($l,t) and test($r,t) and test($d,ads))                           # Parse out dyadic expression
       {pop @s for 1..3;
        push @s, new $d, $l, $r;
        return 1;
       }
      if (test($l,b) and test($r,B) and test($d,t))                             # Parse bracketed term
       {pop @s for 1..3;
        push @s, $d;
        return 1;
       }
     }

    if (@s >= 2)                                                                # Convert ( ) to an empty term
     {my ($r, $l) = reverse @s;
      if (test($l,b) and test($r,B))                                            # Empty pair of brackets
       {pop @s for 1..2;
        push @s, new 'empty1';
        return 1;
       }
      if (!ref($l) and ref($r) and $l =~ m(\Ap))                                # Prefix operator applied to a term
       {pop @s for 1..2;
        push @s, new $l, $r;
        return 1;
       }
      if (!ref($r) and ref($l) and $r =~ m(\Aq))                                # Postfix operator applied to a term
       {pop @s for 1..2;
        push @s, new $r, $l;
        return 1;
       }
      if (!ref($l) and !ref($r) and $l =~ m(\Ab) and $r =~ m(\As))              # Open semi-colon implies one intervening empty term
       {pop @s for 1;
        push @s, new 'empty2';
        push @s, $r;
        return 1;
       }
      if (!ref($l) and !ref($r) and $l =~ m(\As) and $r =~ m(\As))              # Semi-colon, semi-colon implies an empty term
       {pop @s for 1;
        push @s, new 'empty3';
        push @s, $r;
        return 1;
       }
      if (!ref($l) and !ref($r) and $l =~ m(\As) and $r =~ m(\AB))              # Semi-colon, close implies remove unneeded semi
       {pop @s for 1..2;
        push @s, $r;
        return 1;
       }
     }
    if (@s >= 1)                                                                # Convert variable to term
     {my ($t) = reverse @s;
      if (!ref($t) and $t =~ m(\Av))                                            # Single variable
       {pop @s for 1;
        push @s, new $t;
        return 1;
       }
     }
    if (@s == 1)                                                                # Convert leading semi to empty, semi
     {my ($t) = @s;
      if (!ref($t) and $t =~ m(\As))                                            # Semi
       {@s = (new('empty4'), $t);
        return 1;
       }
     }
    undef                                                                       # No move made
   };

  for my $i(keys @e)                                                            # Each input element
   {my $e = $e[$i];
#   lll "AAAA $i $e\n", dump([@s]);

    my sub error($)                                                             # Write an error message
     {my ($m) = @_;                                                             # Error message
      confess "$m on $e at $i\n".dump([@s]). "\n";
     };

     if (!@s)                                                                   # Empty stack
     {error "Expression must start with a variable or open or a prefix operator or a semi"
        if !ref($e) and $e !~ m(\A(b|p|s|v));
      push @s, $e;
      term;
      next;
     }

    my $s = $s[-1];                                                             # Stack has data

    my sub type()                                                               # Type of the current stack top
     {return 't' if ref $s;                                                     # Term on top of stack
      substr($s, 0, 1);                                                         # Something other than a term defines its type by its first letter
     };

    my sub check($)                                                             # Check that the top of the stack has one of the specified elements
     {my ($types) = @_;                                                         # Possible types to match
      return 1 if index($types, type) > -1;                                     # Check type allowed
      confess qq(Expected one of "$types" on $e at $i\nBut got: $s\n);
     };

    my sub test($)                                                              # Check that the second item on the stack contains one of the expected items
     {my ($types) = @_;                                                         # Possible types to match
      return undef unless @s >= 2;                                              # Stack not deep enough so cannot contain any of the specified types
      my $s = ref($s[-2]) ? 't' : substr($s[-2], 0, 1);                         # Type is first character of element
      return 1 if index($types, $s) > -1;
      undef
     };

# a assign
# b open B close
# d dyad
# p prefix
# q suffix
# s semi-colon
# t term
# v variable

    if ($e =~ m(a))                                                             # Assign
     {check("Bqtv");
      1 while test("t");
      push @s, $e;
      next;
     }

    if ($e =~ m(b))                                                             # Open
     {check("abds");
      push @s, $e;
      next;
     }

    if ($e =~ m(B))                                                             # Closing parenthesis
     {check("abqstv");
      1 while term;
      push @s, $e;
      1 while term;
      check("bt");
      #pop @s;
     }

    if ($e =~ m(d))                                                             # Dyad not assign
     {check("Bqtv");
      1 while test("t");
      push @s, $e;
      next;
     }

    if ($e =~ m(p))                                                             # Prefix
     {check("abdps");
      push @s, $e;
      next;
     }

    if ($e =~ m(q))                                                             # Suffix
     {check("Bqtv");
      push @s, $e;
      term;
      next;
     }

    if ($e =~ m(s))                                                             # Semi colon
     {check("Bqstv");
      if ($s =~ m(\As))                                                         # Insert an empty element between two consecutive semicolons
       {push @s, new 'empty5';
        1 while term;
       }
      1 while term;
      push @s, $e;
#     1 while term;
      next;
     }

    if ($e =~ m(v))                                                             # Variable
     {check("abdps");
      push @s, $e;
      term;
      1 while test("p") and term;
      next;
     }
   }

# lll "DDDD\n", dump([@s]);
  pop @s while @s > 1 and $s[-1] =~ m(s);
  1 while term;                                                                 # Assume three is a semio colon at the end
# pop @s while @s > 1 and $s[-1] =~ m(s);

# lll "EEEE\n", dump([@s]);
  @s == 1 or confess "Incomplete expression";
  owf($log, $s[-1]->flat) if -e $log;                                           # Save result if testing
  $s[0]
 } # parse

sub test                                                                        # Test a parse
 {my ($expression, $expected) = @_;                                             # Expression, expected result

  my $got = flat parse(@$expression);
  my $r = $got eq $expected;
  confess "Failed test" unless $r;
  $r
 }

eval {goto latest};

ok test [qw(v1)], <<END;
 v1
END

ok test [qw(s)], <<END;
 empty4
END

ok test [qw(s s)], <<END;
        s
 empty4   empty5
END

ok test [qw(v1 d2 v3)], <<END;
    d2
 v1    v3
END

ok test [qw(v1 a2 v3)], <<END;
    a2
 v1    v3
END

ok test [qw(v1 a2 v3 d4 v5)], <<END;
    a2
 v1       d4
       v3    v5
END

ok test [qw(v1 a2 v3 d4 v5 s6 v8 a9 v10)], <<END;
                s6
    a2                a9
 v1       d4       v8    v10
       v3    v5
END

ok test [qw(v1 a2 v3 s s s  v4 a5 v6 s s)], <<END;
                                       s
                            s            empty5
                   s             a5
          s          empty5   v4    v6
    a2      empty5
 v1    v3
END

ok test [qw(b B)], <<END;
 empty1
END

ok test [qw(b b B B)], <<END;
 empty1
END

ok test [qw(b b v1 B B)], <<END;
 v1
END

ok test [qw(b b v1 a2 v3 B B)], <<END;
    a2
 v1    v3
END

ok test [qw(b b v1 a2 v3 d4 v5 B B)], <<END;
    a2
 v1       d4
       v3    v5
END

ok test [qw(p1 v1)], <<END;
 p1
 v1
END

ok test [qw(p2 p1 v1)], <<END;
 p2
 p1
 v1
END

ok test [qw(v1 q1)], <<END;
 q1
 v1
END

ok test [qw(v1 q1 q2)], <<END;
 q2
 q1
 v1
END
