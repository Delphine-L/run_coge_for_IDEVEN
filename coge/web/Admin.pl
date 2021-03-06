#! /usr/bin/perl -w

use strict;
use CGI;
use CoGe::Accessory::Web;
use CoGe::Accessory::Utils qw(format_time_diff);
use CoGe::Accessory::Jex;
use HTML::Template;
use JSON qw(encode_json);
use Data::Dumper;
use List::Compare;
use CoGeX;
use CoGeX::Result::User;
use Data::Dumper;
use URI::Escape::JavaScript qw(escape unescape);
use Time::Piece;
no warnings 'redefine';

use vars
  qw($P $PAGE_NAME $USER $BASEFILE $coge $cogeweb %FUNCTION $FORM $MAX_SEARCH_RESULTS %ITEM_TYPE $JEX);

$FORM = new CGI;
( $coge, $USER, $P ) = CoGe::Accessory::Web->init( cgi => $FORM );

$JEX =
  CoGe::Accessory::Jex->new( host => $P->{JOBSERVER}, port => $P->{JOBPORT} );

$MAX_SEARCH_RESULTS = 400;

my $node_types = CoGeX::node_types();

#print STDERR $node_types->{user};

%FUNCTION = (
	search_users                    => \&search_users,
	search_stuff                    => \&search_stuff,
	user_info                       => \&user_info,
	add_items_to_user_or_group      => \&add_items_to_user_or_group,
	remove_items_from_user_or_group => \&remove_items_from_user_or_group,
	get_share_dialog                => \&get_share_dialog,
	get_roles                       => \&get_roles,
	search_share                    => \&search_share,
	modify_item                     => \&modify_item,
    cancel_job                      => \&cancel_job,
    restart_job                     => \&restart_job,
    get_jobs                        => \&get_jobs_for_user,
    get_group_dialog                => \&get_group_dialog,
    add_users_to_group              => \&add_users_to_group,
    remove_user_from_group          => \&remove_user_from_group,
    change_group_role               => \&change_group_role,
    get_history_for_user            => \&get_history_for_user,
    toggle_star                     => \&toggle_star,
    update_comment                  => \&update_comment,
);

CoGe::Accessory::Web->dispatch( $FORM, \%FUNCTION, \&gen_html );

sub gen_html {
	#print STDERR "HTML\n";
	my $html;
	my $template =
	  HTML::Template->new( filename => $P->{TMPLDIR} . 'generic_page.tmpl' );

	#$template->param( HELP => '/wiki/index.php?title=ADMIN' );
	$template->param( HELP => $P->{SERVER} );
	my $name = $USER->user_name;
	$name = $USER->first_name if $USER->first_name;
	$name .= " " . $USER->last_name if $USER->first_name && $USER->last_name;
	$template->param( USER       => $name );
	$template->param( PAGE_TITLE => qq{Admin} );
	$template->param( TITLE      => "GODVIEW" );
	$template->param( LOGO_PNG   => "CoGe.svg" );
	$template->param( LOGON      => 1 ) unless $USER->user_name eq "public";
	$template->param( BODY       => gen_body() );
	$template->param( ADJUST_BOX => 1 );
	$template->param( CAS_URL    => $P->{CAS_URL} || '' );
	$html .= $template->output;
}

sub gen_body {

	#print STDERR "BODY\n";
	# Hide this page if the user is not an Admin
	#unless ( $USER->is_admin ) {
	#	my $template =
	#	  HTML::Template->new( filename => $P->{TMPLDIR} . "Admin.tmpl" );
	#	$template->param( ADMIN_ONLY => 1 );
	#	return $template->output;
	#}

	my $template =
	  HTML::Template->new( filename => $P->{TMPLDIR} . 'Admin.tmpl' );
	$template->param( MAIN => 1 );

	#print STDERR $node_types->{user};
	#$template->param( ITEM_TYPE_USER => $node_types->{user} );
	return $template->output;
}

sub search_stuff {
    my %opts        = @_;
    my $search_term = $opts{search_term};
    my $timestamp   = $opts{timestamp};

    my @searchArray = split( ' ', $search_term );
    my @specialTerms;
    my @idList;
    my @results;

    #return unless $search_term;

    #Set up the necessary arrays of serch terms and special conditions
    for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
        if ( index( $searchArray[$i], "::" ) == -1 ) {
            if ( index( $searchArray[$i], '!' ) == -1 ) {
                $searchArray[$i] = { 'like', '%' . $searchArray[$i] . '%' };
            } else {
            	my $bang_index = index($searchArray[$i], '!');
            	my $new_term = substr($searchArray[$i], 0, $bang_index) . substr($searchArray[$i], $bang_index + 1);
            	$searchArray[$i] = { 'not_like', '%' . $new_term . '%' };
            	#print STDERR Dumper($searchArray[$i]);
            }
        }
        else {
            my @splitTerm = split( '::', $searchArray[$i] );
            splice( @searchArray, $i, 1 );
            $i--;
            push @specialTerms, { 'tag' => $splitTerm[0], 'term' => $splitTerm[1] };
        }
    }

	#print STDERR Dumper(\@searchArray);

	#Set the special conditions
	my $type = "none";    #Specifies a particular field to show
	my @restricted =
	  [ -or => [ restricted => 0, restricted => 1 ] ]; 
	  #Specifies either restricted(1) OR unrestriced(0) results. Default is all.
	my @deleted =
	  [ -or => [ deleted => 0, deleted => 1 ] ]; 
	  #Specifies either deleted(1) OR non-deleted(0) results. Default is all.
	for ( my $i = 0 ; $i < @specialTerms ; $i++ ) {
		if ( $specialTerms[$i]{tag} eq 'type' ) {
			$type = $specialTerms[$i]{term};
		}
		if ( $specialTerms[$i]{tag} eq 'restricted' ) {
			@restricted = [ restricted => $specialTerms[$i]{term} ];
			if ( $type eq "none" ) {
				$type = 'restricted'; 
				#Sets the "type" so that only fields relevant to restriction are shown. (i.e. there are no restricted users.)
			}
		}
		if (
			$specialTerms[$i]{tag} eq 'deleted'
			&& (   $specialTerms[$i]{term} eq '0'
				|| $specialTerms[$i]{term} eq '1' )
		  )
		{
			@deleted = [ deleted => $specialTerms[$i]{term} ];
			if ( $type eq "none" ) {
				$type = 'deleted'; 
				#Sets the "type" so that only fields relevant to deletion are shown. (i.e. there are no deleted users).
			}
		}
	}

    # Perform organism search
    if (   $type eq 'none'
        || $type eq 'organism'
        || $type eq 'genome'
        || $type eq 'restricted'
        || $type eq 'deleted' )
    {
        my @orgArray;
        for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
            my $and_or;
            if ($searchArray[$i]{"not_like"}) {
                $and_or = "-and";
			} else {
				$and_or = "-or";
			}
			push @orgArray,
			  [
				$and_or => [
					name        => $searchArray[$i],
					description => $searchArray[$i],
					organism_id => $searchArray[$i]
				]
			  ];
		}
		my @organisms =
		  $coge->resultset("Organism")->search( { -and => [ @orgArray, ], } );

		if ( $type eq 'none' || $type eq 'organism' ) {
			foreach ( sort { $a->name cmp $b->name } @organisms ) {
				push @results,
				  { 'type' => "organism", 'label' => $_->name, 'id' => $_->id, 'description' => $_->description };
			}
		}
		@idList = map { $_->id } @organisms;
	}
	
	#print STDERR "organism done\n";

	# Perform user search
	if ( $type eq 'none' || $type eq 'user' ) {
		my @usrArray;
		for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
			my $and_or;
            if ($searchArray[$i]{"not_like"}) {
                $and_or = "-and";
            } else {
                $and_or = "-or";
            }
			push @usrArray,
			  [
				$and_or => [
					user_name  => $searchArray[$i],
					first_name => $searchArray[$i],
					user_id    => $searchArray[$i],
					first_name => $searchArray[$i]
				]
			  ];
		}
		my @users =
		  $coge->resultset("User")->search( { -and => [ @usrArray, ], } );

		foreach ( sort { $a->user_name cmp $b->user_name } @users ) {
			push @results,
			  { 'type' => "user", 'label' => $_->user_name, 'id' => $_->id };
		}
	}
	
	#print STDERR "user done\n";

	# Perform genome search (corresponding to Organism results)
	if (   $type eq 'none'
		|| $type eq 'genome'
		|| $type eq 'restricted'
		|| $type eq 'deleted' )
	{
		my @genomes = $coge->resultset("Genome")->search(
			{
				-and => [
					organism_id => { -in => \@idList },
					@restricted,
					@deleted,
				],
			}
		);

		foreach ( sort { $a->id cmp $b->id } @genomes ) {
			push @results,
			  {
				'type'          => "genome",
				'label'         => $_->info,
				'id'            => $_->id,
				'deleted'       => $_->deleted,
				'restricted'    => $_->restricted
			  };
		}

		# Perform direct genome search (by genome ID)
		my @genIDArray;
		for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
			push @genIDArray, [ -or => [ genome_id => $searchArray[$i] ] ];
		}
		my @genomeIDs =
		  $coge->resultset("Genome")
		  ->search( { -and => [ @genIDArray, @restricted, @deleted, ], } );

		foreach ( sort { $a->id cmp $b->id } @genomeIDs ) {
			push @results,
			  {
				'type'          => "genome",
				'label'         => $_->info,
				'id'            => $_->id,
				'deleted'       => $_->deleted,
				'restricted'    => $_->restricted
			  };
		}
	}
	
	#print STDERR "genome done\n";

	# Perform experiment search
	if (   $type eq 'none'
		|| $type eq 'experiment'
		|| $type eq 'restricted'
		|| $type eq 'deleted' )
	{
		my @expArray;
		for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
			my $and_or;
            if ($searchArray[$i]{"not_like"}) {
                $and_or = "-and";
            } else {
                $and_or = "-or";
            }
			push @expArray,
			  [
				$and_or => [
					name          => $searchArray[$i],
					description   => $searchArray[$i],
					experiment_id => $searchArray[$i]
				]
			  ];
		}
		my @experiments =
		  $coge->resultset("Experiment")
		  ->search( { -and => [ @expArray, @restricted, @deleted, ], } );

		foreach ( sort { $a->name cmp $b->name } @experiments ) {
			push @results,
			  {
				'type'          => "experiment",
				'label'         => $_->name,
				'id'            => $_->id,
				'deleted'       => $_->deleted,
				'restricted'    => $_->restricted
			  };
		}
	}

    #print STDERR "experiment done\n";

	# Perform notebook search
	if (   $type eq 'none'
		|| $type eq 'notebook'
		|| $type eq 'restricted'
		|| $type eq 'deleted' )
	{
		my @noteArray;
		for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
			my $and_or;
            if ($searchArray[$i]{"not_like"}) {
                $and_or = "-and";
            } else {
                $and_or = "-or";
            }
			push @noteArray,
			  [
				$and_or => [
					name        => $searchArray[$i],
					description => $searchArray[$i],
					list_id     => $searchArray[$i]
				]
			  ];
		}
		my @notebooks =
		  $coge->resultset("List")
		  ->search( { -and => [ @noteArray, @restricted, @deleted, ], } );

		foreach ( sort { $a->name cmp $b->name } @notebooks ) {
			push @results,
			  {
				'type'          => "notebook",
				'label'         => $_->info,
				'id'            => $_->id,
				'deleted'       => $_->deleted,
				'restricted'    => $_->restricted
			  };
		}
	}
	
	#print STDERR "notebook done\n";

	# Perform user group search
	if ( $type eq 'none' || $type eq 'usergroup' || $type eq 'deleted' ) {
		my @usrGArray;
		for ( my $i = 0 ; $i < @searchArray ; $i++ ) {
			my $and_or;
            if ($searchArray[$i]{"not_like"}) {
                $and_or = "-and";
            } else {
                $and_or = "-or";
            }
			push @usrGArray,
			  [
				$and_or => [
					name          => $searchArray[$i],
					description   => $searchArray[$i],
					user_group_id => $searchArray[$i]
				]
			  ];
		}
		my @userGroup =
		  $coge->resultset("UserGroup")
		  ->search( { -and => [ @usrGArray, @deleted, ], } );

		foreach ( sort { $a->name cmp $b->name } @userGroup ) {
			push @results,
			  {
				'type'    => "user_group",
				'label'   => $_->name,
				'id'      => $_->id,
				'deleted' => $_->deleted
			  };
		}
	}

	#print STDERR "Successful search\n";
	return encode_json( { timestamp => $timestamp, items => \@results } );
}

sub user_info {

	my %opts        = @_;
	my $search_term = $opts{search_term};
	my $search_type = $opts{search_type};
	my $timestamp   = $opts{timestamp};

	#print STDERR "$search_term\n";

	my $user;
	if ( $search_type eq "user" ) {
		$user = $coge->resultset("User")->find($search_term);
	}
	if ( $search_type eq "group" ) {
		$user = $coge->resultset("UserGroup")->find($search_term);
	}
	my @results;
	my @users;
	push( @users, $user );

	my $child;
	if ( $search_type eq "user" ) {
		foreach ( $user->child_connectors( { child_type => 6 } ) ) {
			$child = $_->child;
			push( @users, $child );
		}
	}

	foreach my $currentUser (@users) {
		my @current;

		# Find notebooks
		foreach ( $currentUser->child_connectors( { child_type => 1 } ) ) {
			$child = $_->child;
			
			push @current,
			  {
				'type'          => "notebook",
				'label'         => $child->info,
				'id'            => $child->id,
				'role'          => $_->role_id,
				'deleted'        => $child->deleted,
				'restricted'    => $child->restricted
			  };
		}

		# Find genomes
		foreach ( $currentUser->child_connectors( { child_type => 2 } ) ) {
			$child = $_->child;
			push @current,
			  {
				'type'          => "genome",
				'label'         => $child->info,
				'id'            => $child->id,
				'role'          => $_->role_id,
				'deleted'       => $child->deleted,
                'restricted'    => $child->restricted
			  };
		}

		# Find experiments
		foreach ( $currentUser->child_connectors( { child_type => 3 } ) ) {
			$child = $_->child;
			push @current,
			  {
				'type'          => "experiment",
				'label'         => $child->name,
				'id'            => $child->id,
				'info'          => $child->info,
				'role'          => $_->role_id,
				'deleted'       => $child->deleted,
                'restricted'    => $child->restricted
			  };

		}

		# Find users if searching a user group
		if ( $search_type eq "group" ) {
			foreach ( $user->users ) {
				push @current,
				  { 'type' => "user", 'label' => $_->name, 'id' => $_->id };
			}
		}

		push @results,
		  {
			'user'    => $currentUser->name,
			'user_id' => $currentUser->id,
			'result'  => \@current
		  };
	}

	return encode_json( { timestamp => $timestamp, items => \@results } );
}

sub add_items_to_user_or_group {
	my %opts        = @_;
	my $target_item = $opts{target_item};
	return unless $target_item;
	my $role_id = $opts{role_id};
	return unless $role_id;
	my $item_list = $opts{item_list};
	my @items = split( ',', $item_list );
	return unless @items;

	my ( $target_id, $target_type ) = $target_item =~ /(\d+)\:(\d+)/;

	#print STDERR "$target_id $target_type\n";
	return unless ( $target_id and $target_type );

	# Verify that user has access to each item
	my @verified;
	foreach my $item (@items) {
		my ( $item_id, $item_type ) = $item =~ /content_(\d+)_(\d+)/;

		#print STDERR "$item_id $item_type\n";
		next unless ( $item_id and $item_type );

		# print STDERR "add_items_to_user_or_group $item_id $item_type\n";
		if ( $item_type == $node_types->{genome} ) {
			my $genome = $coge->resultset('Genome')->find($item_id);
			next
			  unless ( $USER->has_access_to_genome($genome)
				|| $USER->is_admin );
			push @verified, $item;
		}
		elsif ( $item_type == $node_types->{experiment} ) {
			my $experiment = $coge->resultset('Experiment')->find($item_id);
			next unless $USER->has_access_to_experiment($experiment);
			push @verified, $item;
		}
		elsif ( $item_type == $node_types->{notebook} ) {
			my $notebook = $coge->resultset('List')->find($item_id);
			next unless $USER->has_access_to_list($notebook);
			push @verified, $item;
		}
	}

	#print STDERR Dumper(\@verified);

	# Assign each item to user/group
	# print STDERR "add_items_to_user_or_group $target_id $target_type\n";
	#TODO verify that user can use specified role (for admin/owner roles)
	if ( $target_type == $node_types->{user} ) {
		my $user = $coge->resultset('User')->find($target_id);

		#print STDERR "$user\n";
		return unless $user;

		foreach (@verified) {
			my ( $item_id, $item_type ) = $_ =~ /content_(\d+)_(\d+)/;

			#print STDERR "   user: $item_id $item_type\n";

			# Remove previous connection
			foreach (
				$coge->resultset('UserConnector')->search(
					{
						parent_id   => $target_id,
						parent_type => 5,            # FIXME hardcoded
						child_id    => $item_id,
						child_type  => $item_type
					}
				)
			  )
			{
				$_->delete;
			}

			# Add new connection
			my $conn = $coge->resultset('UserConnector')->create(
				{
					parent_id   => $target_id,
					parent_type => 5,            # FIXME hardcoded
					child_id    => $item_id,
					child_type  => $item_type,
					role_id     => $role_id
				}
			);

			#print STDERR "$conn\n";
			return unless $conn;
		}
	}
	elsif ( $target_type == $node_types->{group} ) {
		my $group = $coge->resultset('UserGroup')->find($target_id);

		return unless $group;

		foreach (@verified) {
			my ( $item_id, $item_type ) = $_ =~ /content_(\d+)_(\d+)/;

			#print STDERR "   group: $item_id $item_type\n";
			#my $var = $group->role_id;
			#print STDERR "$target_id $var\n";

			my $conn = $coge->resultset('UserConnector')->find_or_create(
				{
					parent_id   => $target_id,
					parent_type => 6,                # FIXME hardcoded
					child_id    => $item_id,
					child_type  => $item_type,
					role_id     => $group->role_id
				}
			);
			return unless $conn;
		}
	}

	return get_share_dialog( item_list => $item_list );
}

sub remove_items_from_user_or_group {
	my %opts        = @_;
	my $target_item = $opts{target_item};

	#print STDERR "$target_item\n";
	return unless $target_item;
	my $item_list = $opts{item_list};
	my @items = split( ',', $item_list );

	#print STDERR Dumper(\@items);
	return unless @items;

	my ( $target_id, $target_type ) = $target_item =~ /(\d+)\:(\d+)/;

	#print STDERR "remove target $target_id $target_type\n";
	next unless ( $target_id and $target_type );

	foreach (@items) {
		my ( $item_id, $item_type ) = $_ =~ /content_(\d+)_(\d+)/;

		#print STDERR "remove_item_from_user $item_id $item_type\n";
		next unless ( $item_id and $item_type );

		if ( $item_type == $node_types->{genome} ) {
			my $genome = $coge->resultset('Genome')->find($item_id);
			next unless ( $USER->has_access_to_genome($genome) );

			my $conn = $coge->resultset('UserConnector')->find(
				{
					parent_id   => $target_id,
					parent_type => $target_type,
					child_id    => $genome->id,
					child_type  => $node_types->{genome}
				}
			);
			return unless $conn;

			$conn->delete;
		}
		elsif ( $item_type == $node_types->{experiment} ) {
			my $experiment = $coge->resultset('Experiment')->find($item_id);
			next unless $USER->has_access_to_experiment($experiment);

			my $conn = $coge->resultset('UserConnector')->find(
				{
					parent_id   => $target_id,
					parent_type => $target_type,               #FIXME hardcoded
					child_id    => $experiment->id,
					child_type  => $node_types->{experiment}
				}
			);
			return unless $conn;

			$conn->delete;
		}
		elsif ( $item_type == $node_types->{notebook} ) {
			my $notebook = $coge->resultset('List')->find($item_id);
			next unless $USER->has_access_to_list($notebook);

			my $conn = $coge->resultset('UserConnector')->find(
				{
					parent_id   => $target_id,
					parent_type => $target_type,             #FIXME hardcoded
					child_id    => $notebook->id,
					child_type  => $node_types->{notebook}
				}
			);
			return unless $conn;

			$conn->delete;
		}
	}

	return get_share_dialog( item_list => $item_list );
}

sub get_share_dialog {    #FIXME this routine needs to be optimized
	                      #print STDERR "GetShare called.\n";
	my %opts      = @_;
	my $item_list = $opts{item_list};

	#print STDERR Dumper($item_list);
	my @items = split( ',', $item_list );
	return unless @items;

	my ( %userconn, %notebooks );
	my $isPublic   = 0;
	my $isEditable = 1;
	my $item_id;
	my $item_type;
	foreach (@items) {
		( $item_id, $item_type ) = $_ =~ /content_(\d+)_(\d+)/;

		next unless ( $item_id and $item_type );

		# print STDERR "get_share $item_id $item_type\n";
		if ( $item_type == $node_types->{genome} ) {
			my $genome = $coge->resultset('Genome')->find($item_id);
			next unless ( $USER->has_access_to_genome($genome) );
			map { $userconn{ $_->parent_id } = $_ }
			  ( $genome->user_connectors, $genome->group_connectors );
			map { $notebooks{ $_->id } = $_ } $genome->lists;
			$isPublic = 1 if ( not $genome->restricted );
			$isEditable = 0 if ( not $USER->is_owner_editor( dsg => $genome ) );
		}
		elsif ( $item_type == $node_types->{experiment} ) {
			my $experiment = $coge->resultset('Experiment')->find($item_id);
			next unless $USER->has_access_to_experiment($experiment);
			map { $userconn{ $_->id } = $_ }
			  ( $experiment->user_connectors, $experiment->group_connectors );
			map { $notebooks{ $_->id } = $_ } $experiment->lists;
			$isPublic = 1 if ( not $experiment->restricted );
			$isEditable = 0
			  if ( not $USER->is_owner_editor( experiment => $experiment ) );
		}
		elsif ( $item_type == $node_types->{notebook} ) {
			my $notebook = $coge->resultset('List')->find($item_id);
			next unless $USER->has_access_to_list($notebook);
			map { $userconn{ $_->id } = $_ }
			  ( $notebook->user_connectors, $notebook->group_connectors );
			$isPublic = 1 if ( not $notebook->restricted );
			$isEditable = 0
			  if ( not $USER->is_owner_editor( list => $notebook ) );
		}
	}

	$isEditable = 1 if ( $USER->is_admin );

	my ( %user_rows, %group_rows, %notebook_rows );
	foreach my $conn ( values %userconn ) {
		next
		  unless $conn->role
		; #EL added 10/21/14 so solve a problem for a user where the share dialog wouldn't appear for his genomes, and an fatal error was being thrown due to role->name with role being undefined.  Genomes with problems were IDs: 24576, 24721, 24518, 24515, 24564, 24566, 24568, 24562, 24571
		if ( $conn->is_parent_user ) {
			my $user = $conn->parent;

			$user_rows{ $user->id } = {
				ITEM_ID        => $item_id,
				ITEM_TYPE      => $item_type,
				USER_ITEM      => $user->id . ':' . $conn->parent_type,
				USER_FULL_NAME => $user->display_name,
				USER_NAME      => $user->name,
				USER_ROLE      => $conn->role->name,
				USER_DELETE    => $isEditable
				  && (!$conn->role->is_owner
					|| $USER->is_admin )   # owner can't be removed unless admin
			};
		}
		elsif ( $conn->is_parent_group ) {
			my $group = $conn->parent;

			my @users = map {
				{
					GROUP_USER_FULL_NAME => $_->display_name,
					GROUP_USER_NAME      => $_->name
				}
			} sort usercmp $group->users;

			$group_rows{ $group->id } = {
				ITEM_ID      => $item_id,
				ITEM_TYPE    => $item_type,
				GROUP_ITEM   => $group->id . ':' . $conn->parent_type,
				GROUP_NAME   => $group->name,
				GROUP_ROLE   => $group->role->name,
				GROUP_DELETE => $USER->is_owner_editor( group => $group->id )
				  || $USER->is_admin,
				GROUP_USER_LOOP => \@users
			};
		}
	}

	foreach my $notebook ( values %notebooks ) {
		my %users;

		foreach my $conn ( $notebook->user_connectors ) {
			my $user = $conn->parent;
			next unless $user;
			$users{ $user->id } = {
				NOTEBOOK_USER_FULL_NAME => $user->display_name,
				NOTEBOOK_USER_NAME      => $user->name
			};
		}

		foreach my $conn ( $notebook->group_connectors ) {
			my $group = $conn->parent;
			foreach ( $group->users ) {
				$users{ $_->id } = {
					NOTEBOOK_USER_FULL_NAME => $_->display_name,
					NOTEBOOK_USER_NAME      => $_->name
				};
			}
		}

		$notebook_rows{ $notebook->id } = {
			NOTEBOOK_NAME      => $notebook->name,
			NOTEBOOK_USER_LOOP => [ values %users ]
		};
	}

	my $template =
	  HTML::Template->new( filename => $P->{TMPLDIR} . "Admin.tmpl" );
	$template->param(
		SHARE_DIALOG => 1,
		IS_EDITABLE  => $USER->is_admin || $isEditable,
		GROUP_LOOP =>
		  [ sort { $a->{GROUP_NAME} cmp $b->{GROUP_NAME} } values %group_rows ],
		USER_LOOP => [
			sort { $a->{USER_FULL_NAME} cmp $b->{USER_FULL_NAME} }
			  values %user_rows
		],
		NOTEBOOK_LOOP => [
			sort { $a->{NOTEBOOK_NAME} cmp $b->{NOTEBOOK_NAME} }
			  values %notebook_rows
		],
		ROLES     => get_roles('reader'),
		ITEM_ID   => $item_id,
		ITEM_TYPE => $item_type,
	);

	if ($isPublic) {
		$template->param( ACCESS_MSG => 'Everyone' );
	}

	return $template->output;
}

sub get_group_dialog {
    my %opts      = @_;
    my $item_list = $opts{item_list};
    my @items     = split( ',', $item_list );
    return unless @items;
    my $item_id;
    my $item_type;

    my ( %users, %roles, %creators, %owners, $lowest_role );
    foreach (@items) {
        ( $item_id, $item_type ) = $_ =~ /content_(\d+)_(\d+)/;
        next unless ( $item_id and $item_type );
        next unless ( $item_type == $node_types->{group} ); # sanity check

        my $group = $coge->resultset('UserGroup')->find($item_id);
        next unless ( $group and $group->is_editable($USER) );
        next if ( $group->locked and !$USER->is_admin );

        my $role = $group->role;
        $lowest_role = $role if (!$lowest_role or $role->is_lower($lowest_role));
        my $creator_id = $group->creator_user_id;
        my $owner_id = $group->owner->id;
        foreach my $user ($group->users) {
            my $uid = $user->id;
            $users{$uid} = $user;
            if ( not defined $roles{$uid}
                 or $role->is_lower($roles{$uid}) )
            {
                $roles{$uid} = $role;
            }
            if ($uid == $creator_id) {
                $creators{$uid} = 1;
            }
            if ($uid == $owner_id) {
                $owners{$uid} = 1;
            }
        }
    }

    my @rows;
    foreach my $user ( sort usercmp values %users ) {
        my $uid = $user->id;
        my $role_name;
        if ($creators{$uid}) {
            $role_name = 'Creator';
        }
        if ($owners{$uid}) {
            $role_name = ($role_name ? $role_name . ', ' : '') . 'Owner';
        }
        push @rows, {
        	ITEM_ID      => $item_id,
            ITEM_TYPE    => $item_type,
            USER_ITEM      => $uid,
            USER_FULL_NAME => $user->display_name,
            USER_NAME      => $user->name,
            USER_ROLE      => ($role_name ? ' - ' . $role_name : ''),#$roles{$uid}->name),
            USER_DELETE    => !$owners{$uid} # owner can't be removed
        };
    }

    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . "Admin.tmpl" );

    # If no editable groups then show error dialog
    if (!$USER->is_admin) {
        $template->param(
            ERROR_DIALOG => 1,
            ERROR_MESSAGE => "You don't have permission to modify the selected group(s).",
        );
    }
    else {
        $template->param(
            GROUP_DIALOG => 1,
            IS_EDITABLE  => 1,
            USER_LOOP => \@rows,
            ROLES => get_roles($lowest_role->name),
            ITEM_ID   => $item_id,
            ITEM_TYPE => $item_type,
        );
    }

    return $template->output;
}

sub get_roles {
	my $selected = shift;

	my $html;
	foreach my $role ( $coge->resultset('Role')->all() ) {
		next
		  if ( $role->name =~ /admin/i );   # && !$USER->is_admin); # skip admin
		next if ( $role->name =~ /owner/i && !$USER->is_admin );    # skip owner
		my $name = $role->name;
		$name .= ": " . $role->description if $role->description;

#push @roles, { RID => $role->id, NAME => $name, SELECTED => ($role->id == $selected_role_id) };
		$html .=
		    '<option value="'
		  . $role->id . '" '
		  . (    $role->id eq $selected
			  || $role->name =~ /$selected/i ? 'selected' : '' )
		  . '>'
		  . $role->name
		  . '</option>';
	}
	return $html;
}

sub search_share {
	my %opts = @_;
	return if ( $USER->user_name eq 'public' );
	my $search_term = escape( $opts{search_term} );
	my $timestamp   = $opts{timestamp};

	#print STDERR "search_share $search_term $timestamp\n";

	my @results;

# Search for matching users
# $search_term = '%'.$search_term.'%';
# foreach ($coge->resultset('User')->search_literal(
# 		"user_name LIKE '$search_term' OR first_name LIKE '$search_term' OR last_name LIKE '$search_term'"))
	foreach ( $coge->resultset('User')->all ) {
		next
		  unless ( escape( $_->user_name ) =~ /$search_term/i
			|| escape( $_->display_name ) =~ /$search_term/i );
		my $label = $_->display_name . ' (' . $_->user_name . ')';
		my $value = $_->id . ':' . $node_types->{user};
		push @results, { 'label' => $label, 'value' => $value };
	}

	# Search for matching groups
	foreach ( $coge->resultset('UserGroup')->all ) {
		next unless ( escape( $_->name ) =~ /$search_term/i );
		my $label = $_->name . ' (' . $_->role->name . ' group)';
		my $value = $_->id . ':' . $node_types->{group};
		push @results, { 'label' => $label, 'value' => $value };
	}

	return encode_json( { timestamp => $timestamp, items => \@results } );
}

sub usercmp {
	no warnings 'uninitialized';    # disable warnings for undef values in sort
	$a->display_name cmp $b->display_name;
}

sub modify_item {
	
	unless ( $USER->is_admin ) {
        return 0;
    }
    
    my %opts = @_;
    my $id  = $opts{id};
    my $mod  = $opts{modification};
    my $type = $opts{type};
    print STDERR "$mod $type $id\n";
    return 0 unless $id;

    my $item = $coge->resultset($type)->find($id);
    return 0 unless $item;
    return 0 unless ( $USER->is_admin or $USER->is_owner( dsg => $id ) );
    
    my $log_message;
    if ($mod eq "delete") {
        $log_message = ( $item->deleted ? 'undelete' : 'delete' );
        $item->deleted( !$item->deleted );    # do undelete if already deleted
    } elsif ($mod eq "restrict") {
    	$log_message = ( $item->restricted ? 'unrestrict' : 'restrict' );
    	$item->restricted( !$item->restricted );    # do undelete if already deleted
    }
    $item->update;

    # Record in log
    CoGe::Accessory::Web::log_history(
        db          => $coge,
        user_id     => $USER->id,
        page        => "Admin",
        description => "$log_message $type id $id"
    );

    return 1;
}

sub add_users_to_group {
    my %opts = @_;
    my @target_items = split( ',', $opts{target_items} );
    return unless @target_items;
    my $new_item = $opts{new_item};
    return unless $new_item;
    #print STDERR "add_users_to_group: $new_item @target_items\n";

    # Build a list of users to add to the target group
    my %users;
    my ( $item_id, $item_type ) = $new_item =~ /(\d+)\:(\d+)/;
    return unless ( $item_id and $item_type );

    if ( $item_type == $node_types->{user} ) {
        my $user = $coge->resultset('User')->find($item_id);
        return unless $user;
        $users{$user->id} = $user;
    }
    elsif ( $item_type == $node_types->{group} ) {
        my $group = $coge->resultset('UserGroup')->find($item_id);
        return unless $group;
        # TODO check that user has visibility of this group (one that they own or belong to)
        map { $users{$_->id} = $_ } $group->users;
     }

    # Add users to the target groups
    foreach (@target_items) {
        # Find target group and check permission to modify
        my ( $target_id, $target_type ) = $_ =~ /content_(\d+)_(\d+)/;
        #print STDERR "add_users_to_group $target_id\n";
        next unless ( $target_id and $target_type );
        next unless ( $target_type == $node_types->{group} ); # sanity check
        my $target_group = $coge->resultset('UserGroup')->find($target_id);
        next unless ( $target_group and $target_group->is_editable($USER) );
        next if ( $target_group->locked && !$USER->is_admin );

        # Add users to this target group
        foreach my $user (values %users) {
            # Check for existing user connection to target group
            my $conn = $coge->resultset('UserConnector')->find(
                {
                    parent_id   => $user->id,
                    parent_type => 5,                #FIXME hardcoded to "user"
                    child_id    => $target_id,
                    child_type  => 6                 #FIXME hardcoded to "group"
                }
            );

            # Create new user connection if one wasn't found
            if (!$conn) {
                $conn = $coge->resultset('UserConnector')->create(
                    {
                        parent_id   => $user->id,
                        parent_type => 5,                #FIXME hardcoded to "user"
                        child_id    => $target_id,
                        child_type  => 6,                #FIXME hardcoded to "group"
                        role_id     => $target_group->role_id
                    }
                );
            }
            next unless $conn;

            # Record in log
            CoGe::Accessory::Web::log_history(
                db          => $coge,
                user_id     => $USER->id,
                page        => "Admin",
                description => 'add user id' . $user->id . ' to group id' . $target_id
            );
        }
    }

    return get_group_dialog( item_list => $opts{target_items} );
}

sub remove_user_from_group {
    my %opts = @_;
    my @target_items = split( ',', $opts{target_items} );
    return unless @target_items;
    my $user_id = $opts{user_id};
    return unless $user_id;
    #print STDERR "remove_user_from_group: $user_id @target_items\n";

    # Verify user
    my $user = $coge->resultset('User')->find($user_id);
    return unless $user;

    # Remove users from the target groups
    foreach (@target_items) {
        # Find target group and check permission to modify
        my ( $target_id, $target_type ) = $_ =~ /content_(\d+)_(\d+)/;
        #print STDERR "remove_user_from_group $target_id\n";
        next unless ( $target_id and $target_type );
        next unless ( $target_type == $node_types->{group} ); # sanity check
        my $target_group = $coge->resultset('UserGroup')->find($target_id);
        next unless ( $target_group and $target_group->is_editable($USER) );
        next if ( $target_group->locked && !$USER->is_admin );

        # Get user connection to target group
        my $conn = $coge->resultset('UserConnector')->find(
            {
                parent_id   => $user_id,
                parent_type => 5,                #FIXME hardcoded to "user"
                child_id    => $target_id,
                child_type  => 6                 #FIXME hardcoded to "group"
            }
        );
        next unless $conn;

        # Delete user connection if not owner
        next if ($conn->role->is_owner);
        $conn->delete;

        # Record in log
        CoGe::Accessory::Web::log_history(
            db          => $coge,
            user_id     => $USER->id,
            page        => "Admin",
            description => 'remove user id' . $user_id . ' from group id' . $target_id
        );
    }

    return get_group_dialog( item_list => $opts{target_items} );
}

sub change_group_role {
    my %opts = @_;
    my @target_items = split( ',', $opts{target_items} );
    return unless @target_items;
    my $role_id = $opts{role_id};
    return unless $role_id;
    #print STDERR "change_group_role: $role_id @target_items\n";

    # Verify role
    my $role = $coge->resultset('Role')->find($role_id);
    return unless $role;

    # Change role for the target groups
    foreach (@target_items) {
        # Find target group and check permission to modify
        my ( $target_id, $target_type ) = $_ =~ /content_(\d+)_(\d+)/;
        #print STDERR "change_group_role $target_id\n";
        next unless ( $target_id and $target_type );
        next unless ( $target_type == $node_types->{group} ); # sanity check
        my $target_group = $coge->resultset('UserGroup')->find($target_id);
        next unless ( $target_group and $target_group->is_editable($USER) );
        next if ( $target_group->locked && !$USER->is_admin );

        $target_group->role_id($role_id);
        $target_group->update;
    }

    return get_group_dialog( item_list => $opts{target_items} );
}

#Jobs tab
sub get_jobs_for_user {
	######
    #my $filename = '/home/franka1/repos/coge/web/admin_error.log';
    #open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    #my $print_thing = get_roles($lowest_role->name);
    #print $fh "Get Jobs called\n";
    #print $fh "$size\n";
    #close $fh;
    #print $fh Dumper(\@items);
    
    my @entries;
    if ( $USER->is_admin ) {
        @entries = $coge->resultset('Log')->search(
            #{ description => { 'not like' => 'page access' } },
            {
                type     => { '!='  => 0 },
                workflow_id  => { "!=" => undef}
            },
            { order_by => { -desc => 'time' } },
        );
    }
    else {
        @entries = $coge->resultset('Log')->search(
            {
                user_id => $USER->id,
                workflow_id  => { "!=" => undef},

                #{ description => { 'not like' => 'page access' } }
                type => { '!=' => 0 }
            },
            { order_by => { -desc => 'time' } },
        );
    }

    my %users = map { $_->user_id => $_->name } $coge->resultset('User')->all;
    my @workflows = map { $_->workflow_id } @entries;
    
    my $workflows = $JEX->find_workflows(@workflows);

    my @job_items;
    my %workflow_results;

    foreach (@{$workflows}) {
        my($id, $name, $submitted, $completed, $status) = @{$_};

        my $start_time = localtime($submitted)->strftime('%F %I:%M%P');
        my $end_time = "";
        my $diff;

        if ($completed) {
            $end_time = localtime($completed)->strftime('%F %I:%M%P') if $completed;
            $diff = $completed - $submitted;
        } else {
            $diff = time - $submitted;
        }

        $workflow_results{$id} = {
            status    => $status,
            started   => $start_time,
            completed => $end_time,
            elapsed   => format_time_diff($diff)
        };
    }

    my $index = 1;
    foreach (@entries) {
        my $entry = $workflow_results{$_->workflow_id};

        # A log entry must correspond to a workflow
        next unless $entry;
        
        push @job_items, {
            id => int($index++),
            workflow_id => $_->workflow_id,
            user  => $users{$_->user_id} || "public",
            tool  => $_->page,
            link  => $_->link,
            %{$entry}
        };
    }
    my @filtered;

    # Filter repeated entries
    foreach (reverse @job_items) {
        my $wid = $_->{workflow_id};
        next if (defined $wid and defined $workflow_results{$wid}{seen});
        $workflow_results{$wid}{seen}++ if (defined $wid);

        unshift @filtered, $_;
    }

    return encode_json({ jobs => \@filtered });
}

sub cancel_job {
    my $job_id = _check_job_args(@_);

    return encode_json( {} ) unless defined($job_id);

    my $status = $JEX->get_status( $job_id );

    if ( $status =~ /scheduled|running|notfound/i ) {
        return encode_json({ status => $JEX->terminate( $job_id ) });
    } else {
        return encode_json( {} );
    }
}

sub restart_job {
    my $job_id = _check_job_args(@_);

    return encode_json( {} ) unless defined($job_id);

    my $status = $JEX->get_status( $job_id );

    if ( $status =~ /running/i ) {
        return encode_json( {} );
    } else {
        return encode_json({ status => $JEX->restart( $job_id ) });
    }
}

sub cmp_by_start_time {
    my $job1 = shift;
    my $job2 = shift;

    $job1->start_time cmp $job2->start_time;
}

sub _check_job_args {
    my %args   = @_;
    my $job_id = $args{job};

    if ( not defined($job_id) ) {
        say STDERR "Job.pl: a job id was not given to cancel_job.";
    }

    return $job_id;
}


#History Tab
sub get_history_for_user {
    my %opts       = @_;
    my $time_range = $opts{time_range};    # in hours
    $time_range = 24 if ( not defined $time_range or $time_range !~ /[-\d]/ );
    my $include_page_accesses = $opts{include_pages_accesses};

    my %users = map { $_->user_id => $_->name } $coge->resultset('User')->all;
    my @entries;
    if ( $USER->is_admin ) {
        if ( $time_range == 0 ) {
            @entries = $coge->resultset('Log')->search(

                #{ description => { 'not like' => 'page access' } },
                { type     => { '!='  => 0 } },
                { order_by => { -desc => 'time' } }
            );
        }
    }
    else {
        if ( $time_range == 0 or $time_range == -3 ) {
            @entries = $coge->resultset('Log')->search(
                {
                    user_id => $USER->id,

                    #{ description => { 'not like' => 'page access' } }
                    type => { '!=' => 0 }
                },
                { order_by => { -desc => 'time' } }
            );
        }
    }

    my @items;
    foreach (@entries) {
        push @items,
          {
            id          => $_->id,
            starred     => ( $_->status != 0 ),
            date_time   => $_->time,
            user        => ( $_->user_id ? $users{ $_->user_id } : 'public' ),
            page        => $_->page,
            description => $_->description,
            link        => ( $_->link ? $_->link : '' ),
            comment     => $_->comment
          };
    }

    # print STDERR "items: " . @items . "\n";
    my $filename = '/home/franka1/repos/coge/web/admin_error.log';
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    print $fh Dumper(\@items);
    close $fh;

    return encode_json(\@items);
}

sub toggle_star {
    my %opts   = @_;
    my $log_id = $opts{log_id};

    my $entry = $coge->resultset('Log')->find($log_id);
    return '' unless $entry;

    my $status = $entry->status;
    $entry->status( not $status );
    $entry->update();

    return not $status;
}

sub update_comment {
    my %opts    = @_;
    my $log_id  = $opts{log_id};
    my $comment = $opts{comment};

    # print STDERR "udpate_comment: $log_id $comment\n";

    my $entry = $coge->resultset('Log')->find($log_id);
    return unless $entry;

    $entry->comment($comment);
    $entry->update();
}