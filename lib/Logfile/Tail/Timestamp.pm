package Logfile::Tail::Timestamp;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    my $self = {};
    if (my $globs = delete $args{globs}) {
        ref($globs) eq 'ARRAY' or die "globs must be array";
        $self->{globs} = $globs;
    } else {
        die "Please specify globs";
    }
    die "Unknown arguments: ".join(", ", sort keys %args) if keys %args;

    $self->{_cur_fh} //= {};

    bless $self, $class;
}

sub _switch_cur {
    my ($self, $glob, $filename, $seek_end) = @_;

    #say "D:opening $filename";
    my $fh = IO::File->new($filename, "r") or die "$filename: $!";
    $fh->blocking(0);
    $fh->seek(0, 2) if $seek_end;

    $self->{_cur}{$glob} = $filename;
    $self->{_cur_fh}{$glob} = $fh;
    $self->{_cur_eof}{$glob} = 0;
}

sub getline {
    my $self = shift;

    my $now = time();
    if (!$self->{_last_check_time} || $self->{_last_check_time} < $now - 5) {
        for my $glob (@{ $self->{globs} }) {
            my @files = sort glob($glob);
            next unless @files;
            if (defined $self->{_cur}{$glob}) {
                for (@files) {
                    # there is a newer file than the current one, add to the
                    # pending list of files to be read after the current one
                    $self->{_pending}{$glob}{$_} = 1
                        if $_ gt $self->{_cur}{$glob};
                }
            } else {
                # at the beginning, pick the newest file, open it, and seek to
                # the end
                $self->_switch_cur($glob, $files[-1], 1);
                $self->{_pending}{$glob} = {};
            }
        }
    }

  GLOB:
    for my $glob (keys %{ $self->{_cur_fh} }) {
      READ:
        my $fh = $self->{_cur_fh}{$glob};
        my $line = $fh->getline;
        if (defined $line) {
            return $line;
        } else {
            #say "D:got undef";
            $self->{_cur_eof}{$glob} = 1 if $fh->eof;
            if ($self->{_cur_eof}{$glob}) {
                #say "D:is eof";
                # we are at the end of the file ...
                my @pending = sort keys %{ $self->{_pending}{$glob} };
                if (@pending) {
                    #say "D:has pending file";
                    # if there is another file pending, switch to that file
                    $self->_switch_cur($glob, $pending[0]);
                    delete $self->{_pending}{$glob}{$pending[0]};
                    goto READ;
                } else {
                    #say "D:no pending file";
                    # there is no other file, keep at the current file
                    next GLOB;
                }
            } else {
                #say "D:not eof";
            }
        }
    }
    undef;
}

1;
#ABSTRACT: Tail log lines that are written to timestamped-files

=for Pod::Coverage ^(DESTROY)$

=head1 SYNOPSIS

 use Logfile::Tail::Timestamp;
 use Time::HiRes 'sleep'; # for subsecond sleep

 my $tail = Logfile::Tail::Timestamp->new(
     globs => ["/s/example.com/syslog/http_access.*.log"],
 );

 # tail
 while (1) {
     my $line = $tail->getline;
     if (defined $line) {
         print $line;
     } else {
        sleep 0.1;
     }
 }


=head1 DESCRIPTION

This class can be used to tail log lines from timestamped log files. For
example, on an Spanel server, the webserver is configured to write to daily log
files:

 /s/<SITE-NAME>/syslog/http_access.<YYYY>-<MM>-<DD>.log
 /s/<SITE-NAME>/syslog/https_access.<YYYY>-<MM>-<DD>.log

So, when tailing you will need to switch to a new log file if you cross day
boundary.

When using this class, you specify patterns of files, e.g. C<<
["/s/example.com/syslog/http_access.*.log",
"/s/example.com/syslog/https_access.*.log"] >>. Then you call the C<getline>
method.

This class will first select the newest file (via asciibetical sorting) from
each pattern and tail those files. Then, periodically (by default at most every
5 seconds) the patterns will be checked. If there is one or more newer files,
they will be read in full and then tail-ed, until an even newer file comes
along. For example, this is the list of files in C</s/example.com/syslog> at
time I<t1>:

 http_access.2017-06-05.log.gz
 http_access.2017-06-06.log
 http_access.2017-06-07.log

C<http_access.2017-06-07.log> will first be tail-ed. When
C<http_access.2017-06-08.log> appears at time I<t2>, this file will be read from
start to finish then tail'ed. When C<http_access.2017-06-09.log> appears the
next day, that file will be read then tail'ed. And so on.

Implementation note: for simplicity, the current implementation uses
non-blocking line-based I/O (L<IO::File>'s C<getline>) instead of
select/poll/FAM. This can be a bit slower when there are lots of globs
(basically lots of directories), but the expected typical use-case is only a
single glob/directory.


=head1 METHODS

=head2 Logfile::Tail::Timestamp->new(%args) => obj

Constructor. Arguments:

=head2 $tail->getline() => str|undef


=head1 SEE ALSO

Spanel, L<http://spanel.info>.

L<File::Tail::Dir>

L<IO::Tail>

=cut
