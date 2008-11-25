package CatalystX::CRUD::Controller;
use strict;
use warnings;
use base qw(
    CatalystX::CRUD
    Catalyst::Controller
);
use Carp;
use Catalyst::Utils;
use CatalystX::CRUD::Results;
use Class::C3;
use Data::Dump qw( dump );

__PACKAGE__->mk_accessors(
    qw(
        model_adapter
        form_class
        init_form
        init_object
        model_name
        model_meta
        default_template
        primary_key
        allow_GET_writes
        naked_results
        page_size
        view_on_single_result
        )
);

__PACKAGE__->config(
    primary_key           => 'id',
    view_on_single_result => 0,
    page_size             => 50,
    allow_GET_writes      => 0,
    naked_results         => 0,
);

our $VERSION = '0.34';

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
            model_adapter           => 'FooAdapter', # optional
            model_meta              => { moniker => 'SomeTable' },  # optional
            primary_key             => 'id',
            view_on_single_result   => 0,
            page_size               => 50,
            allow_GET_writes        => 0,
            naked_results           => 0,
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
    $self->next::method( $c, @args ) if $self->next::can;
    1;
}

=head2 default

Attribute: Private

The fallback method. The default returns a 404 error.

=cut

sub default : Path {
    my ( $self, $c, @args ) = @_;
    $c->res->body('Not found');
    $c->res->status(404);
}

=head2 fetch( I<primary_key> )

Attribute: chained to namespace, expecting one argument.

Calls B<do_model> fetch() method with a single key/value pair, 
using the B<primary_key> config value as the key and the I<primary_key> as the value.

The return value of fetch() is saved in stash() as C<object>.

The I<primary_key> value is saved in stash() as C<object_id>.

=cut

sub fetch : Chained('/') PathPrefix CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;
    $c->stash->{object_id} = $id;
    my @pk = $self->get_primary_key( $c, $id );
    my @arg = $id ? (@pk) : ();
    $c->log->debug( "fetch: " . dump \@arg ) if $c->debug;
    $c->stash->{object} = $self->do_model( $c, 'fetch', @arg );
    if ( $self->has_errors($c) or !$c->stash->{object} ) {
        $self->throw_error( 'No such ' . $self->model_name );
    }
}

=head2 get_primary_key( I<context>, I<pk_value> )

Should return an array of the name of the field(s) to fetch() I<pk_value> from
and their respective values.

The default behaviour is to return B<primary_key> and the
corresponding value(s) from I<pk_value>.

However, if you have other unique fields in your schema, you
might return a unique field other than the primary key.
This allows for a more flexible URI scheme.

A good example is Users. A User record might have a numerical id (uid)
and a username, both of which are unique. So if username 'foobar'
has a B<primary_key> (uid) of '1234', both these URIs could fetch the same
record:

 /uri/for/user/1234
 /uri/for/user/foobar

Again, the default behaviour is to return the B<primary_key> field name(s)
from config() (accessed via $self->primary_key) but you can override
get_primary_key() in your subclass to provide more flexibility.

If your primary key is composed of multiple columns, your return value
should include all those columns and their values as extracted
from I<pk_value>. Multiple values are assumed to be joined with C<;;>.
See make_primary_key_string().

=cut

sub get_primary_key {
    my ( $self, $c, $id ) = @_;
    return () unless defined $id and length $id;
    my $pk = $self->primary_key;
    my @ret;
    if ( ref $pk ) {
        my @val = split( m/;;/, $id );
        for my $col (@$pk) {
            push( @ret, $col => shift(@val) );
        }
    }
    else {
        @ret = ( $pk => $id );
    }
    return @ret;
}

=head2 make_primary_key_string( I<object> )

Using value of B<primary_string> constructs a URI-ready
string based on values in I<object>. I<object> is often
the value of:
 
 $c->stash->{object}

but could be any object that has accessor methods with
the same names as the field(s) specified by B<primary_key>.

Multiple values are joined with C<;;> and any C<;> or C</> characters
in the column values are URI-escaped.

=cut

sub make_primary_key_string {
    my ( $self, $obj ) = @_;
    my $pk = $self->primary_key;
    my $id;
    if ( ref $pk ) {
        my @vals;
        for my $field (@$pk) {
            my $v = scalar $obj->$field;
            $v = '' unless defined $v;
            $v =~ s/;/ sprintf( "%%%02X", ';' ) /eg;
            push( @vals, $v );
        }

        # if we had no vals, return undef
        if ( !grep {length} @vals ) {
            return $id;
        }

        $id = join( ';;', @vals );
    }
    else {
        $id = $obj->$pk;
    }

    return $id unless defined $id;

    # must escape any / in $id since passing it to uri_for as-is
    # will break.
    $id =~ s!/!\%2f!g;

    return $id;
}

=head2 create

Attribute: Local

Namespace for creating a new object. Calls to fetch() and edit()
with a B<primary_key> value of C<0> (zero). 

If the Form class has a 'field_value' method, create() will 
pre-populate the Form instance and Object instance
with param-based values (i.e. seeds the form via request params).

Example:

 http://localhost/foo/create?name=bar
 # form and object will have name set to 'bar'

B<NOTE:> This is a GET method named for consistency with the C
in CRUD. It is not equivalent to a POST in REST terminology.

=cut

sub create : Path('create') {
    my ( $self, $c ) = @_;
    $self->fetch( $c, 0 );
    $self->edit($c);

    # allow for params to be passed in to seed the form/object
    my $form = $c->stash->{form};
    my $obj  = $c->stash->{object};
    if ( $form->can('field_value') ) {
        for my $field ( $self->field_names($c) ) {
            if ( exists $c->req->params->{$field} ) {
                $form->field_value( $field => $c->req->params->{$field} );
                if ( $obj->can($field) ) {
                    $obj->$field( $c->req->params->{$field} );
                }
            }
        }
    }

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

=head2 read

Alias for view(), just for consistency with the R in CRUD.

=cut

sub read : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    $self->view($c);
}

=head2 save

Attribute: chained to fetch(), expecting no arguments.

Creates an object with form_to_object(), then follows the precommit(),
save_obj() and postcommit() logic.

See the save_obj(), precommit() and postcommit() hook methods for
ways to affect the behaviour of save().

The special param() value C<_delete> is checked to support POST requests
to /save. If found, save() will detach() to rm().

save() returns 0 on any error, and returns 1 on success.

=cut

sub save : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;

    if ( !$self->allow_GET_writes ) {
        if ( $c->req->method ne 'POST' ) {
            $c->res->status(400);
            $c->res->body('GET request not allowed');
            return;
        }
    }

    if ( $c->request->param('_delete') ) {
        $c->action->name('rm');    # so we can test against it in postcommit()
        $self->rm($c);
        return;
    }

    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    # get a valid object
    my $obj = $self->form_to_object($c);
    if ( !$obj ) {
        $c->log->debug("form_to_object() returned false") if $c->debug;
        return 0;
    }

    # write our changes
    unless ( $self->precommit( $c, $obj ) ) {
        $c->stash->{template} ||= $self->default_template;
        return 0;
    }
    $self->save_obj( $c, $obj );
    $self->postcommit( $c, $obj );

    1;
}

=head2 update

Alias for save(), just for consistency with the U in CRUD.

=cut

sub update : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    $self->save($c);
}

=head2 rm

Attribute: chained to fetch(), expecting no arguments.

Checks the can_write() and has_errors() methods before proceeeding.

Calls the delete() method on the C<object>.

=cut

sub rm : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    if ( !$self->allow_GET_writes ) {
        if ( $c->req->method ne 'POST' ) {
            $c->res->status(400);
            $c->res->body('GET request not allowed');
            return;
        }
    }
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    my $o = $c->stash->{object};

    unless ( $self->precommit( $c, $o ) ) {
        return 0;
    }
    if ( $self->model_adapter ) {
        $self->model_adapter->delete( $c, $o );
    }
    else {
        $o->delete;
    }
    $self->postcommit( $c, $o );
}

=head2 delete

Wrapper for rm(), just for consistency with the D in CRUD.

=cut

sub delete : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    $self->rm($c);
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

=head2 related( I<rel_name>, I<foreign_pk_value> )

Attribute: chained to fetch(), expecting two arguments.

Similar to fetch(), a chain base method for add_related()
and rm_related(). Expects two arguments: I<rel_name>
and I<foreign_pk_value>. Those two values are put in
stash under those key names.

Note that related() has a PathPart of '' so it does
not appear in your URL:

 http://yourhost/foo/123/bars/456/add

will resolve in the action_for add().

=cut

sub related : PathPart('') Chained('fetch') CaptureArgs(2) {
    my ( $self, $c, $rel, $fpk_value ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }
    if ( !$self->allow_GET_writes ) {
        if ( uc( $c->req->method ) ne 'POST' ) {
            $c->res->status(400);
            $c->res->body('GET request not allowed');
            $c->stash->{error} = 1;    # so has_errors() will return true
            return;
        }
    }
    $c->stash( rel_name         => $rel );
    $c->stash( foreign_pk_value => $fpk_value );
}

=head2 remove

Attribute: chained to related().

Dissociate a related many-to-many object of
relationship name I<rel_name> with primary key value I<foreign_pk_value>.

Example:

 http://yoururl/user/123/group/456/remove

will remove user C<123> from the group C<456>.

Sets the 204 (enacted, no content) HTTP response status
on success.

=cut

sub remove : PathPart Chained('related') Args(0) {
    my ( $self, $c ) = @_;
    return if $self->has_errors($c);
    $self->do_model(
        $c, 'rm_related', $c->stash->{object},
        $c->stash->{rel_name},
        $c->stash->{foreign_pk_value}
    );
    $c->res->status(204);    # enacted, no content
}

=head2 add

Attribute: chained to related().

Associate the primary object retrieved in fetch() with
the object with I<foreign_pk_value>
via a related many-to-many relationship I<rel_name>.

Example:

 http://yoururl/user/123/group/456/add

will add user C<123> to the group C<456>.

Sets the 204 (enacted, no content) HTTP response status
on success.

=cut

sub add : PathPart Chained('related') Args(0) {
    my ( $self, $c ) = @_;
    return if $self->has_errors($c);
    $self->do_model(
        $c, 'add_related', $c->stash->{object},
        $c->stash->{rel_name},
        $c->stash->{foreign_pk_value}
    );
    $c->res->status(204);    # enacted, no content
}

=head1 INTERNAL METHODS

The following methods are not visible via the URI namespace but
directly affect the dispatch chain.

=head2 new( I<c>, I<args> )

Sets up the controller instance, detecting and instantiating the model_adapter
if set in config().

=cut

sub new {
    my ( $class, $app_class, $args ) = @_;
    my $self = $class->next::method( $app_class, $args );

    # if model_adapter class is defined, load and instantiate it.
    if ( $self->model_adapter ) {
        Catalyst::Utils::ensure_class_loaded( $self->model_adapter );
        $self->model_adapter(
            $self->model_adapter->new(
                {   model_name => $self->model_name,
                    model_meta => $self->model_meta,
                    app_class  => $app_class,
                }
            )
        );
    }
    return $self;
}

=head2 do_model( I<context>, I<method>, I<args> )

Checks for presence of model_adapter() instance and calls I<method> on either model()
or model_adapter() as appropriate.

=cut

sub do_model {
    my $self   = shift;
    my $c      = shift or $self->throw_error("context required");
    my $method = shift or $self->throw_error("method required");
    if ( $self->model_adapter ) {
        return $self->model_adapter->$method( $self, $c, @_ );
    }
    else {
        return $c->model( $self->model_name )->$method(@_);
    }
}

=head2 model_can( I<context>, I<method_name> )

Returns can() value from model_adapter() or model() as appropriate.

=cut

sub model_can {
    my $self   = shift;
    my $c      = shift or $self->throw_error("context required");
    my $method = shift or $self->throw_error("method name required");
    if ( $self->model_adapter ) {
        return $self->model_adapter->can($method);
    }
    else {
        return $c->model( $self->model_name )->can($method);
    }
}

=head2 form

Returns an instance of config->{form_class}. A single form object is instantiated and
cached in the controller object. If the form object has a C<clear> or C<reset>
method it will be called before returning.

=cut

sub form {
    my ( $self, $c ) = @_;
    $self->{_form} ||= $self->form_class->new;
    if ( $self->{_form}->can('clear') ) {
        $self->{_form}->clear;
    }
    elsif ( $self->{_form}->can('reset') ) {
        $self->{_form}->reset;
    }
    $self->next::method($c) if $self->next::can;
    return $self->{_form};
}

=head2 field_names

Returns an array ref of the field names in form(). By default just calls the field_names()
method on the form(). Your subclass should implement this method if your form class does
not have a field_names() method.

=cut

sub field_names {
    my ($self) = @_;
    return $self->form->field_names;
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

If form_to_object() returns 0, save() will abort at that point in the process,
so form_to_object() should set whatever template and other stash() values
should be used in the response.

Will throw_error() if not overridden.

See CatalystX::CRUD::Controller::RHTMLO for an example.

=cut

sub form_to_object {
    shift->throw_error("must override form_to_object()");
}

=head2 save_obj( I<context>, I<object> )

Calls the update() or create() method on the I<object> (or model_adapter()),
picking the method based on whether C<object_id> in stash() 
evaluates true (update) or false (create).

=cut

sub save_obj {
    my ( $self, $c, $obj ) = @_;
    my $method = $c->stash->{object_id} ? 'update' : 'create';
    if ( $self->model_adapter ) {
        $self->model_adapter->$method( $c, $obj );
    }
    else {
        $obj->$method;
    }
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

    unless ( defined $c->res->location and length $c->res->location ) {
        my $id = $self->make_primary_key_string($o);

        if ( $c->action->name eq 'rm' ) {
            $c->response->redirect( $c->uri_for('') );
        }
        else {
            $c->response->redirect( $c->uri_for( '', $id, 'view' ) );
        }
    }

    1;
}

=head2 uri_for_view_on_single_result( I<context>, I<results> )

Returns 0 unless view_on_single_result returns true.

Otherwise, calls the primary_key() value on the first object
in I<results> and constructs a uri_for() value to the edit()
action in the same class as the current action.

=cut

sub uri_for_view_on_single_result {
    my ( $self, $c, $results ) = @_;
    return 0 unless $self->view_on_single_result;

    # TODO require $results be a CatalystX::CRUD::Results object
    # so we can call next() instead of assuming array ref.
    my $obj = $results->[0];

    my $id = $self->make_primary_key_string($obj);

    # the append . '' is to force stringify anything
    # that might be an object with overloading. Otherwise
    # uri_for() assumes it is an Action object.
    return $c->uri_for( $id . '', $self->can_write($c) ? 'edit' : 'view' );
}

=head2 make_query( I<context>, I<arg> )

This is an optional method. If implemented, do_search() will call this method
and pass the return value on to the appropriate model methods. If not implemented,
the model will be tested for a make_query() method and it will be called instead.

Either the controller subclass or the model B<must> implement a make_query() method.

=cut

=head2 do_search( I<context>, I<arg> )

Prepare and execute a search. Called internally by list()
and search().

Results are saved in stash() under the C<results> key.

If B<naked_results> is true, then results are set just as they are
returned from search() or list() (directly from the Model).

If B<naked_results> is false (default), then results is a
CatalystX::CRUD::Results object.

=cut

sub do_search {
    my ( $self, $c, @arg ) = @_;

    # stash the form so it can be re-displayed
    # subclasses must stick-ify it in their own way.
    $c->stash->{form} ||= $self->form($c);

    # if we have no input, just return for initial search
    if ( !@arg && !$c->req->param && $c->action->name eq 'search' ) {
        return;
    }

    # turn flag on unless explicitly turned off
    $c->stash->{view_on_single_result} = 1
        unless exists $c->stash->{view_on_single_result};

    my $query;
    if ( $self->can('make_query') ) {
        $query = $self->make_query( $c, @arg );
    }
    elsif ( $self->model_can( $c, 'make_query' ) ) {
        $query = $self->do_model( $c, 'make_query', @arg );
    }
    else {
        $self->throw_error(
            "neither controller nor model implement a make_query() method");
    }
    my $count = $self->do_model( $c, 'count', $query ) || 0;
    my $results;
    unless ( $c->stash->{fetch_no_results} ) {
        $results = $self->do_model( $c, 'search', $query );
    }

    if (   $results
        && $count == 1
        && $c->stash->{view_on_single_result}
        && ( my $uri = $self->uri_for_view_on_single_result( $c, $results ) )
        )
    {
        $c->log->debug("redirect for single_result") if $c->debug;
        $c->response->redirect($uri);
    }
    else {

        my $pager;
        if ( $count && $self->model_can( $c, 'make_pager' ) ) {
            $pager = $self->do_model( $c, 'make_pager', $count, $results );
        }

        $c->stash->{results}
            = $self->naked_results
            ? $results
            : CatalystX::CRUD::Results->new(
            {   count   => $count,
                pager   => $pager,
                results => $results,
                query   => $query,
            }
            );
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

primary_key may be a single column name or an array ref of multiple
column names.

=item page_size

=item allow_GET_writes

=item naked_results

=back

=cut

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
