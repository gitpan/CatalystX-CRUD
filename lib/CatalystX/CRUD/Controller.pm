package CatalystX::CRUD::Controller;
use strict;
use warnings;
use base qw(
    CatalystX::CRUD
    Catalyst::Controller
);
use Carp;

our $VERSION = '0.11';

=head1 NAME

CatalystX::CRUD::Controller - base class for CRUD controllers

=head1 SYNOPSIS

    # create a controller
    package MyApp::Controller::Foo;
    use strict;
    use base qw( CatalystX::CRUD::Controller );
    
    __PACKAGE__->config(
                    form_class              => 'MyForm::Foo',
                    init_form               => 'init_with_foo',
                    init_object             => 'foo_from_form',
                    default_template        => 'path/to/foo/edit.tt',
                    model_name              => 'Foo',
                    primary_key             => 'id',
                    view_on_single_result   => 0,
                    page_size               => 50,
                    );
                    
    1;
    
    # now you can manage Foo objects using your MyForm::Foo form class
    # with URIs at:
    #  foo/<pk>/edit
    #  foo/<pk>/view
    #  foo/<pk>/save
    #  foo/<pk>/rm
    #  foo/create
    #  foo/list
    #  foo/search
    
=head1 DESCRIPTION

CatalystX::CRUD::Controller is a base class for writing controllers that
play nicely with the CatalystX::CRUD::Model API. The basic controller API
is based on Catalyst::Controller::Rose::CRUD and Catalyst::Controller::Rose::Search.

See CatalystX::CRUD::Controller::RHTMLO for one implementation.

=head1 CONFIGURATION

See the L<SYNOPSIS> section.

The configuration values are used extensively in the methods
described below and are noted B<in bold> where they are used.

=head1 URI METHODS

The following methods are either public via the default URI namespace or
(as with auto() and fetch()) are called via the dispatch chain. See the L<SYNOPSIS>.

=head2 auto

Attribute: Private

Calls the form() method and saves the return value in stash() as C<form>.

=cut

sub auto : Private {
    my ( $self, $c, @args ) = @_;
    $c->stash->{form} = $self->form($c);
    1;
}

=head2 default

Attribute: Private

The fallback method. The default is simply to write a warning to the Catalyst
log() method.

=cut

sub default : Private {
    my ( $self, $c, @args ) = @_;
    $c->log->warn("no action defined for the default() CRUD method");
}

=head2 fetch( I<primary_key> )

Attribute: chained to namespace, expecting one argument.

Calls B<model_name> read() method with a single key/value pair, 
using the B<primary_key> config value as the key and the I<primary_key> as the value.

The return value of read() is saved in stash() as C<object>.

The I<primary_key> value is saved in stash() as C<object_id>.

=cut

sub fetch : Chained('/') PathPrefix CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    $c->stash->{object_id} = $id;
    $c->log->debug("fetching id = $id") if $c->debug;
    my @arg = $id ? ( $self->primary_key() => $id ) : ();
    $c->stash->{object} = $c->model( $self->model_name )->fetch(@arg);
    if ( $self->has_errors($c) or !$c->stash->{object} ) {
        $self->throw_error( 'No such ' . $self->model_name );
    }
}

=head2 create

Attribute: Local

Namespace for creating a new object. Forwards to fetch() and edit()
with a B<primary_key> value of C<0> (zero).

=cut

sub create : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'fetch', [0] );
    $c->detach('edit');
}

=head2 edit

Attribute: chained to fetch(), expecting no arguments.

Checks the can_write() and has_errors() methods before proceeding.

Populates the C<form> in stash() with the C<object> in stash(),
using the B<init_form> method. Sets the C<template> value in stash()
to B<default_template>.

=cut

sub edit : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }
    my $meth = $self->init_form;
    $c->stash->{form}->$meth( $c->stash->{object} );

    # might get here from create()
    $c->stash->{template} = $self->default_template;
}

=head2 view

Attribute: chained to fetch(), expecting no arguments.

Checks the can_read() and has_errors() methods before proceeding.

Acts the same as edit() but does not set template value in stash().

=cut

sub view : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_read($c) ) {
        $self->throw_error('Permission denied');
        return;
    }
    my $meth = $self->init_form;
    $c->stash->{form}->$meth( $c->stash->{object} );
}

=head2 save

Attribute: chained to fetch(), expecting no arguments.

Creates an object with form_to_object(), then follows the precommit(),
save_obj() and postcommit() logic.

See the save_obj(), precommit() and postcommit() hook methods for
ways to affect the behaviour of save().

The special param() value C<_delete> is checked to support REST-like
behaviour. If found, save() will detach() to rm().

=cut

sub save : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->request->param('_delete') ) {
        $c->action->name('rm');    # so we can test against it in postcommit()
        $c->detach('rm');
    }

    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    # get a valid object
    my $obj = $self->form_to_object($c);

    # write our changes
    unless ( $self->precommit( $c, $obj ) ) {
        $c->stash->{template} ||= $self->default_template;
        return 0;
    }
    $self->save_obj( $c, $obj );
    $self->postcommit( $c, $obj );

    1;
}

=head2 rm

Attribute: chained to fetch(), expecting no arguments.

Checks the can_write() and has_errors() methods before proceeeding.

Calls the delete() method on the C<object>.

=cut

sub rm : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    my $o = $c->stash->{object};

    unless ( $self->precommit( $c, $o ) ) {
        return 0;
    }
    $o->delete;
    $self->postcommit( $c, $o );
}

=head2 list

Attribute: Local

Display all the objects represented by model_name().
The same as calling search() with no params().
See do_search().

=cut

sub list : Local {
    my ( $self, $c, @arg ) = @_;
    unless ( $self->can_read($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    $self->do_search( $c, @arg );
}

=head2 search

Attribute: Local

Query the model and return results. See do_search().

=cut

sub search : Local {
    my ( $self, $c, @arg ) = @_;
    unless ( $self->can_read($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    $self->do_search( $c, @arg );
}

=head2 count

Attribute: Local

Like search() but does not set result values, only a total count.
Useful for AJAX-y types of situations where you want to query for a total
number of matches and create a pager but not actually retrieve any data.

=cut

sub count : Local {
    my ( $self, $c, @arg ) = @_;
    unless ( $self->can_read($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    $c->stash->{fetch_no_results} = 1;

    $self->do_search( $c, @arg );
}

=head1 INTERNAL METHODS

The following methods are not visible via the URI namespace but
directly affect the dispatch chain.

=head2 form

Returns an instance of config->{form_class}. A single form object is instantiated and
cached in the controller object. If the form object has a C<clear> or C<reset>
method it will be called before returning.

=cut

sub form {
    my $self = shift;
    $self->{_form} ||= $self->form_class->new;
    if ( $self->{_form}->can('clear') ) {
        $self->{_form}->clear;
    }
    elsif ( $self->{_form}->can('reset') ) {
        $self->{_form}->reset;
    }
    return $self->{_form};
}

=head2 can_read( I<context> )

Returns true if the current request is authorized to read() the C<object> in
stash().

Default is true.

=cut

sub can_read {1}

=head2 can_write( I<context> )

Returns true if the current request is authorized to create() or update()
the C<object> in stash().

=cut

sub can_write {1}

=head2 form_to_object( I<context> )

Should return an object ready to be handed to save_obj(). This is the primary
method to override in your subclass, since it will handle all the form validation
and population of the object.

Will throw_error() if not overridden.

See CatalystX::CRUD::Controller::RHTMLO for an example.

=cut

sub form_to_object {
    shift->throw_error("must override form_to_object()");
}

=head2 save_obj( I<context>, I<object> )

Calls the update() or create() method on the I<object>, picking the method
based on whether C<object_id> in stash() evaluates true (update) or false (create).

=cut

sub save_obj {
    my ( $self, $c, $obj ) = @_;
    my $method = $c->stash->{object_id} ? 'update' : 'create';
    $obj->$method;
}

=head2 precommit( I<context>, I<object> )

Called by save(). If precommit() returns a false value, save() is aborted.
If precommit() returns a true value, save_obj() gets called.

The default return is true.

=cut

sub precommit {1}

=head2 postcommit( I<context>, I<object> )

Called in save() after save_obj(). The default behaviour is to issue an external
redirect resolving to view().

=cut

sub postcommit {
    my ( $self, $c, $o ) = @_;
    my $pk = $self->primary_key;

    if ( $c->action->name eq 'rm' ) {
        $c->response->redirect( $c->uri_for('') );
    }
    else {
        $c->response->redirect(
            $c->uri_for( '', $o->delegate->$pk, 'view' ) );
    }

    1;
}

=head2 view_on_single_result( I<context>, I<results> )

Returns 0 unless the config() key of the same name is true.

Otherwise, calls the primary_key() value on the first object
in I<results> and constructs a uri_for() value to the edit()
action in the same class as the current action.

=cut

sub view_on_single_result {
    my ( $self, $c, $results ) = @_;
    return 0 unless $self->config->{view_on_single_result};
    my $pk  = $self->primary_key;
    my $obj = $results->[0];

    # the append . '' is to force stringify anything
    # that might be an object with overloading. Otherwise
    # uri_for() assumes it is an Action object.
    return $c->uri_for( $obj->$pk . '', 'edit' );
}

=head2 do_search( I<context>, I<arg> )

Prepare and execute a search. Called internally by list()
and search().

=cut

sub do_search {
    my ( $self, $c, @arg ) = @_;

    # stash the form so it can be re-displayed
    # subclasses must stick-ify it in their own way.
    $c->stash->{form} ||= $self->form;

    # if we have no input, just return for initial search
    if ( !@arg && !$c->req->param && $c->action eq 'search' ) {
        return;
    }

    # turn flag on if explicitly turned off
    $c->stash->{view_on_single_result} = 1
        unless exists $c->stash->{view_on_single_result};

    my $query = $c->model( $self->model_name )->make_query(@arg);
    my $count = $c->model( $self->model_name )->count($query) || 0;
    my $results;
    unless ( $c->stash->{fetch_no_results} ) {
        $results = $c->model( $self->model_name )->search($query);
    }
    if (   $count == 1
        && ( my $uri = $self->view_on_single_result( $c, $results ) )
        && $c->stash->{view_on_single_result} )
    {
        $c->response->redirect($uri);
    }
    elsif ( $count == 0 ) {
        $c->stash->{results} = { count => $count, results => $results };
    }
    else {
        $c->stash->{results} = {
            count => $count,
            pager => $c->model( $self->model_name )
                ->make_pager( $count, $results ),
            results => $results,
            query   => $query,
        };
    }
}

=head1 CONVENIENCE METHODS

The following methods simply return the config() value of the same name.

=over

=item form_class

=item init_form

=item init_object

=item model_name

=item default_template

=item primary_key

=item page_size

=back

=cut

sub form_class       { shift->config->{form_class} }
sub init_form        { shift->config->{init_form} }
sub init_object      { shift->config->{init_object} }
sub model_name       { shift->config->{model_name} }
sub default_template { shift->config->{default_template} }
sub primary_key      { shift->config->{primary_key} }

# see http://use.perl.org/~LTjake/journal/31738
# PathPrefix will likely end up in an official Catalyst RSN.
# This lets us have a sane default fetch() method without having
# to write one in each subclass.
sub _parse_PathPrefix_attr {
    my ( $self, $c, $name, $value ) = @_;
    return PathPart => $self->path_prefix;
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

This module based on Catalyst::Controller::Rose::CRUD by the same author.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
