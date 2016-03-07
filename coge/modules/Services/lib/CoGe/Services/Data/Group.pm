package CoGe::Services::Data::Group;

use Mojo::Base 'Mojolicious::Controller';
#use IO::Compress::Gzip 'gzip';
use CoGeX;
use CoGe::Services::Auth;

sub search {
    my $self = shift;
    my $search_term = $self->stash('term');

    # Authenticate user and connect to the database
    my ($db, $user) = CoGe::Services::Auth::init($self);

    # Deny a public user access to groups
    unless ($user && !$user->is_public) {
        $self->render(json => {
            error => { Auth => "Access denied" }
        }, status => 401);
        return;
    }

    # Validate input
    if (!$search_term or length($search_term) < 3) {
        $self->render(json => { error => { Error => 'Search term is shorter than 3 characters' } });
        return;
    }

    # Search groups
    my $search_term2 = '%' . $search_term . '%';
    my @groups = $db->resultset("UserGroup")->search(
        \[
            'user_group_id = ? OR name LIKE ? OR description LIKE ?',
            [ 'user_group_id', $search_term ],
            [ 'name', $search_term2 ],
            [ 'description', $search_term2 ],
        ]
    );

    # Format response
    my @result = map {
      {
        id => int($_->id),
        name => $_->name,
        description => $_->description,
        role => {
            name => $_->role->name,
            description => $_->role->description
        }
      }
    } @groups;

    $self->render(json => { groups => \@result });
}

sub fetch {
    my $self = shift;
    my $id = int($self->stash('id'));

    # Authenticate user and connect to the database
    my ($db, $user) = CoGe::Services::Auth::init($self);

    # Deny a public user access to any group
    unless ($user && !$user->is_public) {
        $self->render(json => {
            error => { Auth => "Access denied"}
        }, status => 401);
        return;
    }

    # Get group
    my $group = $db->resultset("UserGroup")->find($id);
    unless (defined $group) {
        $self->render(json => {
            error => { Error => "Item not found" }
        });
        return;
    }

    $self->render(json => {
        id => int($group->id),
        name => $group->name,
        description => $group->description,
        role => {
            name => $group->role->name,
            description => $group->role->description
        },
        users => [ map { int($_->id) } $group->users ]
    });
}

sub items {
    my $self = shift;
    my $id = int($self->stash('id'));

    # Authenticate user and connect to the database
    my ($db, $user) = CoGe::Services::Auth::init($self);

    # Deny a public user access to any group
    unless ($user && !$user->is_public) {
        $self->render(json => {
            error => { Auth => "Access denied" }
        }, status => 401);
        return;
    }

    # Get group
    my $group = $db->resultset("UserGroup")->find($id);
    unless (defined $group) {
        $self->render(json => {
            error => { Error => "Item not found" }
        });
        return;
    }

    # Restrict access to users in the group
    unless ($group->has_member($user)) {
        $self->render(json => {
            error => { Auth => "Access denied" }
        }, status => 401);
        return;
    }

    # Format experiments
    my @experiments = map {
        {
            id => int($_->id),
            type => "experiment",
        }
    } $group->experiments;

    # Format Genomes
    my @genomes = map {
        {
            id => int($_->id),
            type => "genome",
        }
    } $group->genomes;

    # Format Lists
    my @notebooks = map {
        {
            id => int($_->id),
            type => "notebook"
        }
    } $group->lists;

    $self->render(json => {
        items => [@experiments, @genomes, @notebooks]
    });
}

1;
