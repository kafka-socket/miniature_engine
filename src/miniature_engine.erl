-module(miniature_engine).

-include_lib("kernel/include/logger.hrl").

-export([
    start/0,
    stop_gracefully/0
]).

-spec start() -> ok.
start() ->
    ok = logger:set_primary_config(level, log_level()),
    ok = wait_for_kafka(),
    ok = start_kafka_client(miniature_engine_producer),
    ok = start_kafka_client(miniature_engine_consumer),
    {ok, _Pid} = start_cowboy(),
    ok.

-spec stop_gracefully() -> ok.
stop_gracefully() ->
    ok = ranch:suspend_listener(http),
    ok = lists:foreach(fun(Pid) ->
        Pid ! stop_gracefully
    end, miniature_engine_channels:all()),
    ok = ranch:wait_for_connections(http, '==', 0).

-spec start_kafka_client(atom()) -> ok.
start_kafka_client(ClientId) ->
    brod:start_client(endpoints(), ClientId, [
        {auto_start_producers, true},
        {extra_sock_opts, kafka_socket_options()}
    ]).

-spec start_cowboy() -> {ok, pid()}.
start_cowboy() ->
    cowboy:start_clear(http,
        _TransportOpts = http_socket_options(),
        _ProtocolOpts  = #{env => #{dispatch => dispatch()}}
    ).

-spec endpoints() -> [brod:endpoint()].
endpoints() ->
    {ok, EndpointsString} = application:get_env(kafka_endpoints),
    endpoints(EndpointsString).

-spec endpoints(string() | binary()) -> [brod:endpoint()].
endpoints(EndpointsString) when is_binary(EndpointsString) ->
    endpoints(binary_to_list(EndpointsString));
endpoints(EndpointsString) ->
    lists:map(fun(Endpoint) ->
        [Host, Port] = string:split(Endpoint, ":"),
        {Host, list_to_integer(Port)}
    end, string:split(EndpointsString, ",", all)).

-spec port() -> non_neg_integer().
port() ->
    {ok, Port} = application:get_env(port),
    Port.

-spec dispatch() -> cowboy_router:dispatch_rules().
dispatch() ->
    cowboy_router:compile([{'_', [
        {"/ws", miniature_engine_websocket_handler, []},
        {"/health", miniature_engine_healthcheck_handler, []}
    ]}]).

-spec log_level() -> atom().
log_level() ->
    application:get_env(miniature_engine, log_level, notice).

-spec wait_for_kafka() -> ok.
wait_for_kafka() ->
    Result = try
        brod_utils:get_metadata(endpoints(), all, #{extra_sock_opts => kafka_socket_options()})
    catch
        throw : Throw ->
            {error, Throw};
        error : Error ->
            {error, Error}
    end,
    wait_for_kafka(Result).

-spec wait_for_kafka({atom(), any()}) -> ok.
wait_for_kafka({ok, _Metadata}) ->
    ok;
wait_for_kafka({error, Error}) ->
    ?LOG_ERROR("Kafka unavailable. Bootstrap endpoints are ~p due to ~p", [endpoints(), Error]),
    timer:sleep(timer:seconds(2)),
    wait_for_kafka().

-spec kafka_socket_options() -> list().
kafka_socket_options() ->
    kafka_socket_options(is_ipv6_enabled()).

kafka_socket_options(false) ->
    [];
kafka_socket_options(_) ->
    [inet6].

-spec http_socket_options() -> list().
http_socket_options() ->
    http_socket_options(is_ipv6_enabled()).

http_socket_options(false) ->
    [{port, port()}];
http_socket_options(_) ->
    [{port, port()}, inet6].

is_ipv6_enabled() ->
    application:get_env(miniature_engine, ipv6, false).
