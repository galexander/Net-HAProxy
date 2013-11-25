use strict;
use warnings;
use Net::HAProxy;
use Test::More tests => 13;
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

    my $line;

    my $weight; my $initial;
    ($weight, $initial) = $ha->get_weight("pxname", "svname");
    $line = <$pipe>;
    is $line, "get weight pxname/svname\n", "get weight";

    $ha->set_weight("pxname", "svname", 100);
    $line = <$pipe>;
    is $line, "set weight pxname/svname 100\n", "set weight absolute 100";

    my $_initial;
    ($weight, $_initial) = $ha->get_weight("pxname", "svname");
    $line = <$pipe>;
    is $line, "get weight pxname/svname\n", "get weight absolute 100 (initial 1)";
    is $weight, 100, "weight set";
    is $_initial, $initial, "initial weight consistent";

    $ha->set_weight("pxname", "svname", "5%");
    $line = <$pipe>;
    is $line, "set weight pxname/svname 5%\n", "set weight relative 5%";

    $ha->set_weight("pxname", "svname", "100%");
    $line = <$pipe>;
    is $line, "set weight pxname/svname 100%\n", "set weight relative 100%";

    $ha->reset_weight("pxname", "svname");
    $line = <$pipe>;
    is $line, "get weight pxname/svname\n", "reset weight (get)";
    $line = <$pipe>;
    is $line, "set weight pxname/svname $initial\n", "reset weight (set)";
    ($weight, $_initial) = $ha->get_weight("pxname", "svname");
    $line = <$pipe>;
    is $line, "get weight pxname/svname\n", "get weight absolute 100 (initial 1)";
    is $weight, $initial, "weight reset";
    is $_initial, $initial, "initial weight consistent";


    kill TERM => $pid;
    wait;
    unlink $path;

} else {
    my $weight = my $initial = 1;
    CLIENT:
    while (defined (my $client = $mock->accept)) {
        while (defined (my $cmd = <$client>)) {
            if ($cmd =~ /set weight \w+\/\w+ (\S+)/) {
                my $value = $1;
                if ($value =~ /^\d+$/) {
                    $weight = $value;
                } else {
                    if($value =~ /(\d+)%/) {
                        $weight = int($1 / 100 * $weight);
                    } else {
                        print $client "error";
                    }
                }
                printf $client "\n";
            } else {
                printf $client "%d (initial %d)\n", $weight, $initial;
            }
            print $cmd;
            $client->close;
            next CLIENT;
        }
    }
    exit 0;
}
