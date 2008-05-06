package CatalystX::CRUD::Model::File;
use strict;
use warnings;
use base qw( CatalystX::CRUD::Model );
use File::Find;
use Carp;
use Data::Dump qw( dump );
use Path::Class::File;
use Class::C3;

our $VERSION = '0.26';

=head1 NAME

CatalystX::CRUD::Model::File - filesystem CRUD model

=head1 SYNOPSIS

 package MyApp::Model::Foo;
 use base qw( CatalystX::CRUD::Model::File );
 __PACKAGE__->config->{object_class} = 'MyApp::File';
 __PACKAGE__->config->{inc_path} = [ '/some/path', '/other/path' ];
 
 1;
 
=head1 DESCRIPTION

CatalystX::CRUD::Model::File is an example implementation of CatalystX::CRUD::Model.

=head1 METHODS

Only new or overridden methods are documented here.

=cut

=head2 Xsetup

Implements the CXC::Model API. Sets the C<inc_path> config (if not already set)
to the C<root> config value.

=cut

sub Xsetup {
    my ( $self, $c ) = @_;
    $self->config->{inc_path} ||= [ $c->config->{root} ];
    $self->next::method($c);
}

=head2 new_object( file => I<path/to/file> )

Return a new CatalystX::CRUD::Object::File object.

=cut

=head2 fetch( file => I<path/to/file> )

Read I<path/to/file> from disk and return a CXCO::File object.

I<path/to/file> is assumed to be in C<inc_path>

If I<path/to/file> is empty or cannot be found, the
CatalystX::CRUD::Object::File object is returned but its content()
will be undef. If its parent dir is '.', its dir() 
will be set to the first item in inc_path().

=cut

sub fetch {
    my $self = shift;
    my $file = $self->new_object(@_);

    # look through inc_path
    for my $dir ( @{ $self->inc_path } ) {
        my $test = $self->object_class->new(
            file => Path::Class::File->new( $dir, $file ) );

        if ( -s $test ) {
            $file = $test;
            $file->read;
            last;
        }
    }

    # test if we found it or not
    if ( $file->dir eq '.' ) {
        $file = $self->object_class->new(
            file => Path::Class::File->new( $self->inc_path->[0], $file ) );
    }

    return $file;
}

=head2 inc_path

Returns the include path from config(). The include path is searched
by search(), count() and iterator().

=cut

sub inc_path { shift->config->{inc_path} }

=head2 make_query

Returns a I<wanted> subroutine suitable for File::Find.

 # TODO regex vs exact match
 
=cut

sub make_query {
    my ($self) = @_;
    return sub {1};
}

=head2 search( I<filter_CODE> )

Uses File::Find to search through inc_path() for files.
I<filter_CODE> should be a CODE ref matching format returned by make_query().
If not set, make_query() is called by default.

Returns an array ref of CXCO::File objects.

=cut

sub search {
    my $self = shift;
    my $filter_sub = shift || $self->make_query;
    my %files;
    my $find_sub = sub {

        carp "File::Find::Dir = $File::Find::dir\nfile = $_\n";
        return unless $filter_sub->($_);
        $files{$File::Find::name}++;
    };
    find( $find_sub, @{ $self->inc_path } );

    carp dump \%files;

    return [ map { $self->new_object( file => $_ ) } sort keys %files ];
}

=head2 count( I<filter_CODE> )

Returns number of files matching I<filter_CODE>. See search for a description
of I<filter_CODE>.

=cut

sub count {
    my $self = shift;
    my $filter_sub = shift || $self->make_query;
    my $count;
    my $find_sub = sub {
        carp "File::Find::Dir = $File::Find::dir\nfile = $_\n";
        return unless $filter_sub->($_);
        $count++;
    };
    find( $find_sub, @{ $self->inc_path } );
    return $count;
}

=head2 iterator( I<filter_CODE> )

Acts same as search() but returns a CatalystX::CRUD::Iterator::File
object instead of a simple array ref.

=cut

sub iterator {
    my $self  = shift;
    my $files = $self->search(@_);
    return CatalystX::CRUD::Iterator::File->new($files);
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
