# Tests for Connector::Proxy::Proc::SafeExec
#

use strict;
use warnings;
use English;
use Try::Tiny;

use Test::More tests => 24;

use Log::Log4perl;
Log::Log4perl->easy_init( { level   => 'ERROR' } );

#diag "LOAD MODULE\n";

our $req_err;

BEGIN {
    eval 'require Proc::SafeExec;';
    our $req_err = $@;

#    diag("SAFEXEC: req_err='$req_err'");

    #    use_ok( 'Connector::Proxy::Proc::SafeExec' );
}

#diag "Connector::Proxy::Proc::SafeExec\n";
###########################################################################
SKIP: {
    skip "Proc::SafeExec not installed", 22 if $req_err;

    require_ok('Connector::Proxy::Proc::SafeExec');
    my $conn = Connector::Proxy::Proc::SafeExec->new(
        {   LOCATION => 't/config/test.sh',
            args     => ['foo'],
            content => '[% payload %]',
            timeout  => 2,
        }
    );

    ok( defined $conn );

    is( $conn->get(), 'foo', 'Simple invocation' );

    $conn->args( [ '--quote-character', '**', 'foo' ] );
    is( $conn->get(), '**foo**', 'Multiple arguments and options' );

    my $exception;
    $conn->args( [ '--exit-with-error', '1' ] );

    undef $exception;
    try {
        $conn->get();
    }
    catch {
        $exception = $_;
    };
    like(
        $exception,
        qr/^System command exited with return code/,
        'Error code handling'
    );

    $conn->args( [ '--sleep', '1', 'foo' ] );
    is( $conn->get(), 'foo', 'Timeout: not triggered' );

    $conn->args( [ '--sleep', '3', 'foo' ] );
    undef $exception;
    try {
        $conn->get();
    }
    catch {
        $exception = $_;
    };
    like( $exception, qr/^System command timed out/, 'Timeout: triggered' );

    ####
    # argument passing tests
    $conn->args( ['abc[% ARGS.0 %]123'] );
    is( $conn->get('foo'), 'abcfoo123',
        'Passing parameters from get arguments' );

    $conn->args( ['abc[% ARGS.0 %]123[% ARGS.1 %]xyz'] );
    is( $conn->get( [ 'foo', 'bar' ] ),
        'abcfoo123barxyz', 'Multiple parameters from get arguments' );

    ###
    # environment tests
    $ENV{MYVAR} = '';
    $conn->args( [ '--printenv', 'MYVAR' ] );
    is( $conn->get('foo'), '', 'Environment variable test: no value' );

    $ENV{MYVAR} = 'bar';
    is( $conn->get('foo'), 'bar',
        'Environment variable test: externally set' );

    $ENV{MYVAR} = '';
    $conn->env( { MYVAR => '1234', } );
    is( $conn->get('foo'), '1234',
        'Environment variable test: internally set to static value' );

    $conn->env( { MYVAR => '1234[% ARGS.0 %]', } );
    is( $conn->get('foo'), '1234foo',
        'Environment variable test: internally set with template' );

    ###
    # stdin tests
    $conn->stdin('54321');
    $conn->args( ['--'] );
    is( $conn->get('foo'), '54321', 'Passing scalar data via STDIN 1/2' );
    is( $conn->get('bar'), '54321', 'Passing scalar data via STDIN 2/2' );

    $conn->stdin('54321[% ARGS.0 %]abc');
    is( $conn->get('foo'), '54321fooabc',
        'Passing data via STDIN with template' );

    $conn->stdin( [ '1234[% ARGS.0 %]abc', '4321[% ARGS.1 %]def' ] );
    is( $conn->get( [ 'foo', 'bar' ] ), '1234fooabc
4321bardef', 'Passing multiple lines via STDIN'
    );


    is($conn->get_meta()->{TYPE}, 'connector', 'Identifies as connector');
    is($conn->get_meta('foo')->{TYPE}, 'scalar', 'Identifies as scalar');

    ok ($conn->exists(''), 'Connector exists');
    ok ($conn->exists('foo'), 'Node Exists');
    ok ($conn->exists( [ 'foo' ] ), 'Node Exists Array');


    # basic tests for set
    $conn->stdin();
    $conn->args(['--echo','[% FILE %]']);
    like( $conn->set('foo', { payload => "Hello World" } ), qr@/tmp/\w+/\w+@ , 'Creating file');

    $conn->args(['--cat','[% FILE %]']);
    is( $conn->set('foo', { payload => 'Hello World' } ), 'Hello World', 'Writing file');

}

