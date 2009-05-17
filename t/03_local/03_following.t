use strict;
use warnings;
use Test::More tests => 5;
use POE qw(Component::Github);
use Test::POE::Server::TCP;
use POE::Filter::HTTP::Parser;
use JSON::Any;
use HTTP::Response;

my $payload = {
                      'users' => [
                                   'bricas',
                                   'Ovid',
                                   'audreyt',
                                   'rjbs',
                                   'schwern',
                                   'xantus',
                                   'abh',
                                   'acme',
                                   'sungo',
                                   'nothingmuch',
                                   'dagolden',
                                   'andk',
                                   'rafl',
                                   'miyagawa',
                                   'AndyA',
                                   'barbie',
                                   'hinrik',
                                   'perigrin',
                                   'apocalypse'
                                 ]
};

my $httpd = Test::POE::Server::TCP->spawn(
	address => '127.0.0.1',
	filter  => POE::Filter::HTTP::Parser->new( type => 'server' ),
	prefix  => 'httpd_',
);


my $github = POE::Component::Github->spawn( url_path => '127.0.0.1:' . $httpd->port . '/api/v2/json' );
isa_ok( $github, 'POE::Component::Github');

POE::Session->create(
  package_states => [
	'main' => [qw(_start _github httpd_registered httpd_client_input)],
  ],
);

$poe_kernel->run();
pass("Okay the kernel returned");
exit 0;

sub _start {
  $poe_kernel->post( $httpd->session_id, 'register', 'all' );
  return;
}

sub httpd_registered {
  $poe_kernel->post( $github->get_session_id, 'user', 'following', { event => '_github', user => 'bingos' }, );
  return;
}

sub httpd_client_input {
  my ($id,$input) = @_[ARG0,ARG1];
  is( $input->uri->as_string, '/api/v2/json/user/show/bingos/following', 'The URI was right.' );
  my $resp = HTTP::Response->new( 200 );
  $resp->protocol('HTTP/1.1');
  $resp->content( JSON::Any->new->objToJson( $payload ) );
  use bytes;
  $resp->header('Content-Length', length $resp->content);
  $resp->header('Content-Type', 'application/json; charset=utf-8');
  $httpd->send_to_client( $id, $resp );
  return;
}

sub _github {
  my $args = $_[ARG0];
  ok( $args->{data}, 'There appears to be some data' );
  is_deeply( $args->{data}, $payload, 'The data was good' );
  $poe_kernel->post( $github->get_session_id, 'shutdown' );
  $httpd->shutdown();
  return;
}
