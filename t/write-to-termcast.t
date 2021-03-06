#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::TCP';

use App::Termcast;

no warnings 'redefine';
local *App::Termcast::_termsize = sub { return (80, 24) };
use warnings 'redefine';

pipe(my $cread, my $swrite);
pipe(my $sread, my $cwrite);

alarm 60;

test_tcp(
    client => sub {
        my $port = shift;
        close $swrite;
        close $sread;
        { sysread($cread, my $buf, 1) }
        my $tc = App::Termcast->new(
            host     => '127.0.0.1',
            port     => $port,
            user     => 'test',
            password => 'tset',
        );
        $tc->write_to_termcast('foo');
        syswrite($cwrite, 'a');
        { sysread($cread, my $buf, 1) }
        ok(!$tc->meta->find_attribute_by_name('_term')->has_value($tc),
           "pty isn't created");
    },
    server => sub {
        my $port = shift;
        close $cwrite;
        close $cread;
        my $sock = IO::Socket::INET->new(LocalAddr => '127.0.0.1',
                                         LocalPort => $port,
                                         Listen    => 1);
        $sock->accept; # signal to the client that the port is available
        syswrite($swrite, 'a');
        my $client = $sock->accept;
        is(full_read($client),
           "hello test tset\n\e\[H\x00{\"geometry\":[80,24]}\xff\e\[H\e\[2J",
           "got the correct login info");
        $client->send("hello, test\n");
        { sysread($sread, my $buf, 1) }

        is(full_read($client), "foo");
        syswrite($swrite, 'a');
        sleep 1 while $client->connected;
    },
);

sub full_read {
    my ($fh) = @_;

    my $select = IO::Select->new($fh);
    return if $select->has_exception(0.1);

    1 while !$select->can_read(1);

    my $ret;
    while ($select->can_read(1)) {
        my $new;
        sysread($fh, $new, 4096);
        last unless defined($new) && length($new);
        $ret .= $new;
        return $ret if $select->has_exception(0.1);
    }

    return $ret;
}

done_testing;
