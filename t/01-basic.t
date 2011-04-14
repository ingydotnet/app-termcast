#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Requires 'Test::TCP';
use IO::Pty::Easy;

use App::Termcast;

test_tcp(
    client => sub {
        my $port = shift;
        my $inc = join ':', grep { !ref } @INC;
        my $client_script = <<EOF;
        BEGIN { \@INC = split /:/, '$inc' }
        use App::Termcast;
        my \$tc = App::Termcast->new(host => '127.0.0.1', port => $port,
                                    user => 'test', password => 'tset');
        \$tc->run('$^X', "-e", "print 'foo'");
EOF
        my $pty = IO::Pty::Easy->new;
        $pty->spawn("$^X", "-e", $client_script);
        is($pty->read, 'foo', 'got the right thing on stdout');
        sleep 1; # because the server gets killed when the client exits
    },
    server => sub {
        my $port = shift;
        my $sock = IO::Socket::INET->new(LocalAddr => '127.0.0.1',
                                         LocalPort => $port,
                                         Listen    => 1);
        $sock->accept; # signal to the client that the port is available
        my $client = $sock->accept;
        my $login;
        $client->recv($login, 4096);
        my $auth_regexp = qr/^hello test tset\n\e\[H\x00.+?\xff\e\[H\e\[2J/;
        like($login, $auth_regexp, 'got the correct login info');
        $client->send("hello, test\n");
        my $output;
        $client->recv($output, 4096);
        is($output, "foo", 'sent the right data to the server');
    },
);

done_testing;
