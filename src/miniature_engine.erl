-module(miniature_engine).

-include_lib("kernel/include/logger.hrl").

-export([
    start/0,
    stop_gracefully/0
]).

start() ->
    ok = logger:set_primary_config(level, log_level()),
    {ok, _Pid} = start_cowboy(),
    ok = wait_for_kafka(),
    ok = start_kafka_client(miniature_engine_producer),
    ok = start_kafka_client(miniature_engine_consumer).

stop_gracefully() ->
    ok = ranch:suspend_listener(http),
    ok = lists:foreach(fun(Pid) ->
        Pid ! stop_gracefully
    end, miniature_engine_channels:all()),
    ok = ranch:wait_for_connections(http, '==', 0).


start_kafka_client(ClientId) ->
    brod:start_client(endpoints(), ClientId, [{auto_start_producers, true}]).

start_cowboy() ->
    cowboy:start_clear(http,
        _TransportOpts = [{port, port()}],
        _ProtocolOpts  = #{env => #{dispatch => dispatch()}}
    ).

endpoints() ->
    {ok, EndpointsString} = application:get_env(kafka_endpoints),
    endpoints(EndpointsString).

endpoints(EndpointsString) when is_binary(EndpointsString) ->
    endpoints(binary_to_list(EndpointsString));
endpoints(EndpointsString) ->
    lists:map(fun(Endpoint) ->
        [Host, Port] = string:split(Endpoint, ":"),
        {Host, list_to_integer(Port)}
    end, string:split(EndpointsString, ",", all)).

port() ->
    {ok, Port} = application:get_env(port),
    Port.

dispatch() ->
    cowboy_router:compile([{'_', [
        {"/ws", miniature_engine_websocket_handler, []},
        {"/health", miniature_engine_healthcheck_handler, []}
    ]}]).

log_level() ->
    application:get_env(miniature_engine, log_level, notice).

wait_for_kafka() ->
    Result = try
        brod:get_metadata(endpoints())
    catch
        throw:Throw ->
            {error, Throw};
        error:Error ->
            {error, Error}
    end,
    wait_for_kafka(Result).

wait_for_kafka({ok, _Metadata}) ->
    ok;
wait_for_kafka({error, Error}) ->
    ?LOG_ERROR("Kafka unavailable. Bootstrap endpoints are ~p due to ~p", [endpoints(), Error]),
    timer:sleep(timer:seconds(2)),
    wait_for_kafka().
