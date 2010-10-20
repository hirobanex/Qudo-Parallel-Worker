package Qudo::Parallel::Worker;
use strict;
use warnings;
use base 'Qudo::Worker';
our $VERSION = '0.01';

sub set_job_status { 1 }

sub work{
    my ($class,$job) = @_;

    my $self = bless {
        _child_jobs => [],
        _min_child_priority => ''
    }, $class;

    $self->parallel_work($job);

    $job->completed;
}

sub add_child_job {
    my ($self,$funcname,$args,$warning_message_off) = @_;

    $args->{priority} = $self->_set_child_priority($args->{priority});
    
    $args->{priority} = $self->_set_min_child_priority($args->{priority});
    
    unless($warning_message_off){
        unless($args->{uniqkey}){
            warn "missing uniqkey...you can't use default_watchdog method in 'Qudo::Parallel::Worker::Watchdog'";
        }

        unless($funcname){
            warn "missing funcname...you can't use default_watchdog method in 'Qudo::Parallel::Worker::Watchdog'";
        }
    }
    
    push @{$self->{_child_jobs}}, +{
        funcname => $funcname,
        args     => $args,
    };

}

sub _set_child_priority{
    my ($self,$child_priority) =@_;

    unless($child_priority){
        $child_priority = 1;
    }

    return $child_priority;
}

sub _set_min_child_priority{
    my ($self,$child_priority) =@_;

    if(!$self->{_min_child_priority} || (($self->{_min_child_priority}||0) > $child_priority)){
        $self->{_min_child_priority} = $child_priority;
    }
}

sub start_child_job {
    my ($self,$job,$watchdog,$args) = @_;

    $job or die "missing main job...";
    $watchdog or die "missing watch dog class...";

    my $manager = $job->manager;
    my $db = $manager->driver_for($job->db);
   
    $manager->register_hooks(qw/Qudo::Hook::Serialize::JSON/);#jsonにしてしまった・・・ここのエンキューだけフック指定ってできたっけ？

    $args = $self->_setting_args($watchdog,$args);

    $db->dbh->begin_work;

        for my $child_job (@{$self->{_child_jobs}}) {
            $manager->enqueue($child_job->{funcname}, $child_job->{args});
        }
        $manager->enqueue($watchdog, $args);

    $db->dbh->commit;
}

sub _setting_args{
    my ($self,$watchdog,$args) = @_;

    $args->{arg}->{child_jobs} = $self->{_child_jobs};

    if(defined($args->{run_after})){
        $args->{run_after} = $watchdog->retry_delay;
    }
    
    if(defined($args->{priority})){
        if($args->{priority} > $self->{_min_child_priority}){
            warn 'watchdog arg priority is bigger than minimum priority in child_jobs';
            $args->{priority} = $self->{_min_child_priority} - 1;
        }
    }

    return $args;
}
1;
__END__

=head1 NAME

Qudo::Parallel::Worker -

=head1 SYNOPSIS

  use Qudo::Parallel::Worker;

=head1 DESCRIPTION

Qudo::Parallel::Worker is

=head1 AUTHOR

Atsushi Kobayashi E<lt>nekokak _at_ gmail _dot_ comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
