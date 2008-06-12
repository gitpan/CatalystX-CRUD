package CatalystX::CRUD::Results;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use Carp;
use Class::C3;

__PACKAGE__->mk_ro_accessors(qw( count pager query results ));

our $VERSION = '0.27';

=head1 NAME

CatalystX::CRUD::Results - search results class

=head1 SYNOPSIS

 # in .tt file
 Your search returned [% results.count %] total hits.
 Your query was [% results.query %].
 You are on page [% results.pager.current_page %].
 [% FOREACH r IN results.results %]
  [% loop.count %]: [% r.name %]
 [% END %]

=head1 DESCRIPTION

CatalystX::CRUD::Results is a class for search results from a
CatalystX::CRUD::Controller.  See the do_search() method
in CatalystX::CRUD::Controller.

=head1 METHODS

The following read-only accessors are available:

=head2 count

Returns total number of results.

=head2 pager

Returns Data::Pageset object for paging through results.

=head2 query

Returns the search query.

=head2 results

Returns array ref of current found objects.

=cut

=head2 next

Returns next result. If results() is an arrayref, shift() is used.
Otherwise, the results() value is assumed to act like a 
CatalystX::CRUD::Iterator and its next() method will be called.

=cut

sub next {
    my $self = shift;
    return unless defined $self->results;

    if ( ref( $self->results ) eq 'ARRAY' ) {
        return shift @{ $self->{results} };
    }
    else {
        return $self->results->next;
    }
}

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

Copyright 2008 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
