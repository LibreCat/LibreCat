package LibreCat::Hook::audit_message;

# Code to submit audit messages (if configured)

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

has name => (is => 'ro', default => sub { '' });
has type => (is => 'ro', default => sub { '' });

sub fix {
    my ($self, $data) = @_;

    my $name = $self->name;
    my $type = $self->type;

    h->log->debug("entering audit_message() hook from : $name ($type)");

    if (0) {}
    elsif ($name eq 'publication-new') {
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => '<new>' ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => 'get /librecat/record/new' ,
            message => "creating a new $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'publication-edit') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => "get /librecat/record/edit/$id" ,
            message => "editing a $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'publication-update') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => "post /librecat/record/update" ,
            message => "update a $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'publication-publish') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => "post /librecat/record/publish/$id" ,
            message => "publishing a $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'publication-delete') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => "get /librecat/record/delete/$id" ,
            message => "deleting a $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'publication-return') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::publication' ,
            action  => "get /librecat/record/return/$id" ,
            message => "returning a $record_type by $user_id" ,
        });
    }
    elsif ($name eq 'qae-new') {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::qae' ,
            action  => "post /librecat/upload/qae/submit" ,
            message => "qua import a $record_type by $user_id" ,
        });
    }
    elsif ($name =~ /^import-new-(\S+)/) {
        my $id          = $data->{_id};
        my $record_type = $data->{type}    // '<unknown>';
        my $user_id     = $data->{user_id} // '<unknown>';
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => 'LibreCat::App::Catalogue::Route::importer' ,
            action  => "post /librecat/record/import" ,
            message => "$1 import a $record_type by $user_id" ,
        });
    }

    $data;
}

1;
