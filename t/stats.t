use strict;
use warnings;
use Net::HAProxy;
use Test::More tests => 3;
use IO::Socket::UNIX;
use File::Temp qw(tempdir);
use File::Spec;
use Try::Tiny;

my $path = tempdir(CLEANUP => 1);
$path = File::Spec->catfile($path, 'haproxy.socket');
my $mock = IO::Socket::UNIX->new(Type => SOCK_STREAM,
                                 Local => $path,
                                 Listen => 1);

my $pid = open my $pipe, "-|";
defined $pid
    or die "fork(): $!";

if ($pid) {
    # parent;
    my $ha = Net::HAProxy->new(socket => $path)
        or die "$!";
    isa_ok $ha, 'Net::HAProxy';

    $ha->stats;
    my $line;
    $line = <$pipe>;
    is $line,"show stat -1 -1 -1\n", "show stat";

    $ha->stats({iid => 1, type => 2, sid => 1});
    $line = <$pipe>;
    is $line,"show stat 1 2 1\n", "show stat with parameters";
    kill TERM => $pid;

    wait;
    unlink $path;

} else {
    CLIENT:
    while (defined (my $client = $mock->accept)) {
        while (defined (my $cmd = <$client>)) {
            print $client "# dummy\n\n";
            print $cmd;
            $client->close;
            next CLIENT;
        }
    }
    exit 0;
}
