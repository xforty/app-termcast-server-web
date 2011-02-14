package App::Termcast::Server::Web::App;
use strict;
use warnings;
use parent 'Plack::Component';

use Plack::Util::Accessor qw(tc_socket tt connections hippie);
use Plack::Builder;
use Plack::App::Cascade;
use Web::Hippie::App::JSFiles;
use AnyMQ;

use App::Termcast::Server::Web::Dispatcher;
use App::Termcast::Server::Web::Hippie::Handle;

sub call {
    my ($self, $env) = @_;

    my $app = builder {
        mount '/_hippie' => builder {
            enable "+Web::Hippie";
            enable "+Web::Hippie::Pipe", bus => AnyMQ->new;
            sub {
                my ($env) = @_;

                my $h = $env->{'hippie.handle'};

                if ($env->{PATH_INFO} eq '/new_listener') {
                    my $stream_id = $env->{'hippie.args'};

                    my $stream = $self->connections->get_stream($stream_id);

                    my $hh = App::Termcast::Server::Web::Hippie::Handle->new(
                        stream => $stream_id,
                        handle => $h,
                        lines => $stream->lines,
                        cols  => $stream->cols,
                    );

                    $self->hippie->hippie_handles->insert($hh);

                    # send buffer to get the viewer caught up
                    $hh->send_to_browser($stream->buffer);
                }
                else {
                    if ($env->{PATH_INFO} eq '/error') {
                        $self->hippie->handles->remove($h) if $h;
                    }
                }
                return [ '200', [ 'Content-Type' => 'application/hippie' ], [ "" ] ]
            }
        };

        mount '/' => builder {
            enable 'Plack::Middleware::Static',
                path => qr!^/?(?:static/|favicon\.ico)!, root => 'web/';

            my $dispatch_app = sub {
                my ($env) = @_;
                #use Data::Dumper::Concise; warn Dumper($env);

                my $dispatch = App::Termcast::Server::Web::Dispatcher->dispatch(
                    $env->{PATH_INFO},
                    tt          => $self->tt,
                    connections => $self->connections,
                );

                my $body;
                if ( $dispatch->has_matches) {
                    my $match = ($dispatch->matches)[0];
                    $body = $match->run(
                        tt          => $self->tt,
                        connections => $self->connections,
                    );
                }
                else {
                    return [ '404', [ 'Content-Type' => 'text/plain' ], [ "File Not Found" ] ];
                }

                return [ '200', [ 'Content-Type' => 'text/html' ], [ $body ] ];
            };


            Plack::App::Cascade->new(
                apps => [
                    Web::Hippie::App::JSFiles->new->to_app(),
                    $dispatch_app,
                ]
            );
        };

    };

    return $app->($env);
}

1;