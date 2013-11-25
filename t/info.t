use strict;
use warnings;
use Net::HAProxy;
use Test::More tests => 2;
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
    isa_ok $ha, "Net::HAProxy";

    $ha->info;
    my $line = <$pipe>;
    is $line,"show info\n", "show info";

    wait;
    unlink $path;

} else {
    my $client = $mock->accept;
    my $cmd = <$client>;
    print $client "# dummy\n";
    print $cmd;
    exit 0;
}
