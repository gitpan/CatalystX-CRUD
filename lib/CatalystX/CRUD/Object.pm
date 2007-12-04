package CatalystX::CRUD::Object;
use strict;
use warnings;
use base qw( CatalystX::CRUD Class::Accessor::Fast );
use Carp;

__PACKAGE__->mk_ro_accessors(qw( delegate ));

our $VERSION = '0.16';

=head1 NAME

CatalystX::CRUD::Object - an instance returned from a CatalystX::CRUD::Model

=head1 SYNOPSIS

 package My::Object;
 use base qw( CatalystX::CRUD::Object );
 
 sub create { shift->delegate->save }
 sub read   { shift->delegate->load }
 sub update { shift->delegate->save }
 sub delete { shift->delegate->remove }
 
 1;

=head1 DESCRIPTION

A CatalystX::CRUD::Model returns instances of CatalystX::CRUD::Object.

The assumption is that the Object knows how to manipulate the data it represents,
typically by holding an instance of an ORM or other data model in the
C<delegate> accessor, and calling methods on that instance.

So, for example, a CatalystX::CRUD::Object::RDBO has a Rose::DB::Object instance,
and calls its RDBO object's methods.

The idea is to provide a common CRUD API for various backend storage systems.

=head1 METHODS

The following methods are provided.

=cut

=head2 new

Generic constructor. I<args> may be a hash or hashref.

=cut

sub new {
    my $class = shift;
    my $arg = ref( $_[0] ) eq 'HASH' ? $_[0] : {@_};
    return $class->SUPER::new($arg);
}

=head2 delegate

The delegate() accessor is a holder for the object instance that the CXCO instance
has. A CXCO object "hasa" instance of another class in its delegate() slot. The
delegate is the thing that does the actual work; the CXCO object just provides a container
for the delegate to inhabit.

Think of delegate as a noun, not a verb, as in "The United Nations delegate often
slept here."


=head1 REQUIRED METHODS

A CXCO subclass needs to implement at least the following methods:

=over

=item create

Write a new object to store.

=item read

Load a new object from store.

=item update

Write an existing object to store.

=item delete

Remove an existing object from store.

=back

=cut

sub create { shift->throw_error("must implement create") }
sub read   { shift->throw_error("must implement read") }
sub update { shift->throw_error("must implement update") }
sub delete { shift->throw_error("must implement delete") }

1;
__END__

=head1 AUTHOR

Peter Karman, C<< <perl at peknet.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalystx-crud at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CatalystX-CRUD>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CatalystX::CRUD

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CatalystX-CRUD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CatalystX-CRUD>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-CRUD>

=item * Search CPAN

L<http://search.cpan.org/dist/CatalystX-CRUD>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
