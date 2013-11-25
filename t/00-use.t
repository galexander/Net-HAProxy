use strict;
use warnings;
use Test::More tests => 2;
use_ok 'Net::HAProxy';
can_ok 'Net::HAProxy',
            qw(new
               stats
               info
               enable_server
               disable_server
               set_weight
               reset_weight);
