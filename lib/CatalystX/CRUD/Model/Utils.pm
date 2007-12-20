package CatalystX::CRUD::Model::Utils;
use strict;
use warnings;
use base qw( CatalystX::CRUD Class::Accessor::Fast );
use Sort::SQL;
__PACKAGE__->mk_accessors(qw( use_ilike ne_sign ));

our $VERSION = '0.18';

=head1 NAME

CatalystX::CRUD::Model::Utils - helpful methods for your CRUD Model class

=head1 SYNOPSIS

 package MyApp::Model::Foo;
 use base qw( 
    CatalystX::CRUD::Model
    CatalystX::CRUD::Model::Utils
  );
 # ... 
 1;
 
=head1 DESCRIPTION

CatalystX::CRUD::Model::Utils provides helpful not non-essential methods
for CRUD Model implementations. Stick it in your @ISA to help reduce the
amount of code you have to write yourself.

=head1 METHODS

=head2 use_ilike( boolean )

Convenience accessor to flag requests in params_to_sql_query()
to use ILIKE instead of LIKE SQL command.

=head2 ne_sign( I<string> )

What string to use for 'not equal' in params_to_sql_query().
Defaults to '!='.

=cut

=head2 make_sql_query( [ I<field_names> ] )

Returns a hashref suitable for passing to a SQL-oriented model.

I<field_names> should be an array of valid form field names.
If false or missing, will call $c->controller->field_names().

The following reserved request param names are implemented:

=over

=item _order

Sort order. Should be a SQL-friendly string parse-able by Sort::SQL.

=item _sort

Instead of _order, can pass one column name to sort by.

=item _dir

With _sort, pass the direction in which to sort.

=item _page_size

For the Data::Pageset pager object. Defaults to page_size(). An upper limit of 200
is implemented by default to reduce the risk of a user [unwittingly] creating a denial
of service situation.

=item _page

What page the current request is coming from. Used to set the offset value
in the query. Defaults to C<1>.

=item _offset

Pass explicit row to offset from in query. If not present, deduced from
_page and _page_size.

=item _no_page

Ignore _page_size, _page and _offset and do not return a limit
or offset value.

=back

=cut

sub make_sql_query {
    my $self        = shift;
    my $c           = $self->context;
    my $field_names = shift
        || $c->controller->field_names
        || $self->throw_error("field_names required");

    my $p2q = $self->params_to_sql_query($field_names);
    my $sp
        = Sort::SQL->string2array( $c->req->param('_order')
            || join( ' ', $c->req->param('_sort'), $c->req->param('_dir') )
            || ( $c->controller->primary_key . ' DESC' ) );
    my $s         = join( ' ', map { each %$_ } @$sp );
    my $offset    = $c->req->param('_offset');
    my $page_size = $c->request->param('_page_size') || $self->page_size;

    # don't let users DoS us. unless they ask to (see _no_page).
    $page_size = 200 if $page_size > 200;

    my $page = $c->req->param('_page') || 1;

    if ( !defined($offset) ) {
        $offset = ( $page - 1 ) * $page_size;
    }

    # normalize since some ORMs require UPPER case
    $s =~ s,\b(asc|desc)\b,uc($1),eg;

    my %query = (
        query           => $p2q->{sql},
        sort_by         => $s,
        limit           => $page_size,
        offset          => $offset,
        sort_order      => $sp,
        plain_query     => $p2q->{query},
        plain_query_str => $self->sql_query_as_string( $p2q->{query} ),
    );

    # undo what we've done if asked.
    if ( $c->req->param('_no_page') ) {
        delete $query{limit};
        delete $query{offset};
    }

    return \%query;

}

=head2 sql_query_as_string( params_to_sql_query->{query} )

Returns the request params as a SQL WHERE string.

=cut

sub sql_query_as_string {
    my ( $self, $q ) = @_;
    my @s;
    for my $p ( sort keys %$q ) {
        my @v = @{ $q->{$p} };
        next unless grep {m/\S/} @v;
        push( @s, "$p = " . join( ' or ', @v ) );
    }
    return join( ' AND ', @s );
}

=head2 params_to_sql_query( I<field_names> )

Convert request->params into a SQL-oriented
query.

Returns a hashref with two key/value pairs:

=over

=item sql

Arrayref of ORM-friendly SQL constructs.

=item query

Hashref of column_name => raw_values_as_arrayref.

=back

Called internally by make_sql_query().

=cut

sub params_to_sql_query {
    my ( $self, $field_names ) = @_;
    my $c = $self->context;
    my ( @sql, %query );
    my $ne = $self->ne_sign || '!=';
    my $like = $self->use_ilike ? 'ilike' : 'like';

    for my $p (@$field_names) {

        next unless exists $c->req->params->{$p};
        my @v    = $c->req->param($p);
        my @safe = @v;
        next unless grep { defined && m/./ } @safe;

        $query{$p} = \@v;

        # normalize wildcards and set sql
        if ( grep {/[\%\*]|^!/} @v ) {
            grep {s/\*/\%/g} @safe;
            my @wild = grep {m/\%/} @safe;
            if (@wild) {
                push( @sql, ( $p => { $like => \@wild } ) );
            }

            # allow for negation of query
            my @not = grep {m/^!/} @safe;
            if (@not) {
                push( @sql, ( $p => { $ne => [ grep {s/^!//} @not ] } ) );
            }
        }
        else {
            push( @sql, $p => [@safe] );
        }
    }

    return { sql => \@sql, query => \%query };
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

=head1 COPYRIGHT & LICENSE

Copyright 2007 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut