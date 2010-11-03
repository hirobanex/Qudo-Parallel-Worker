package Qudo::Parallel::Worker::Watchdog;
use strict;
use warnings;
use base 'Qudo::Worker';

sub max_retries { 10 }
sub retry_delay { 10 }

sub work{
    my ($class,$job) = @_;
    
    my $watchdog = $class->can('custom_watchdog') || $class->can('default_watchdog');#まどろっこしいから継承で上書きしちゃう？

    if($watchdog->($job)){
        if($class->can('after_work')){
            $class->after_work($job);
        }

        $job->completed;
    }
}

#alter.sqlはどうしよっか？
#jsonでfuncとuniqkeyをもってきて、いるのが前提だけど・・・・
sub default_watchdog{
    my  $job = shift;

    my $db         = $job->manager->{qudo}->driver_for($job->db);

    my $child_job_count    = scalar(@{$job->arg->{child_jobs}});
    my $ok_child_job_count = 0;

    for my $child_job(@{$job->arg->{child_jobs}}){
        $ok_child_job_count += $db->search_by_sql(
            q{
                SELECT job_status.id
                FROM job_status
                INNER JOIN func ON job_status.func_id = func.id
                WHERE 
                    job_status.status  = 'completed' AND
                    func.name          = ?           AND
                    job_status.uniqkey = ?
            },
            [$child_job->{func},$child_job->{key}],
        )->count;
    #    $ok_child_job_count += _is_child_job($child_job,$db);
    }

    if($ok_child_job_count != $child_job_count){
        die "ok_child_job_count --- $ok_child_job_count, child_job_count --- $child_job_count";
        return 0;
    }else{
        return 1;
    }
}

#生SQLってよくないとかだったらこちらを採用
sub _is_child_job{
    my ($child_job,$db) = @_;
    
    my $rs = $db->resultset();
    
    $rs->add_select('job_status.id');
    $rs->add_join(job_status => {
        type      => 'inner',
        table     => 'func',
        condition => 'job_status.func_id = func.id',
    });
    $rs->add_where('job_status.status' => 'completed');
    $rs->add_where('job_status.uniqkey' => $child_job->{key});
    $rs->add_where('func.name' => $child_job->{func});
    
    my $itr = $rs->retrieve;
    
    return $itr->count;
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
