-module(miniature_engine_websocket_handler).

-include_lib("kernel/include/logger.hrl").

-behaviour(cowboy_websocket).

-export([
    init/2,
    websocket_init/1,
    websocket_handle/2,
    websocket_info/2,
    terminate/3
]).

init(Req, State) ->
    Qs = cowboy_req:parse_qs(Req),
    Ua = cowboy_req:header(<<"user-agent">>, Req),
    Token = proplists:get_value(<<"token">>, Qs),
    ?LOG_DEBUG("Token is ~p", [Token]),
    {ok, Decoded} = jwt:decode(Token, jwt_key()),
    User = maps:get(user_claim_key(), Decoded),
    {cowboy_websocket, Req, [{user, User}, {ua, Ua}] ++ State}.

websocket_init(State) ->
    User = proplists:get_value(user, State),
    true = gproc:reg({p, l, {user, User}}),
    {ok, TRef} = timer:send_interval(5000, self(), ping),
    {ok, [{ping_timer, TRef} | State]}.

websocket_handle(ping, State) ->
    ?LOG_DEBUG("ping received"),
    {reply, pong, State};
websocket_handle(pong, State) ->
    ?LOG_DEBUG("pong received"),
    {ok, State};
websocket_handle({text, Message}, State) ->
    ?LOG_DEBUG("Text message received ~p", [Message]),
    User = proplists:get_value(user, State),
    Reply = case produce(User, Message) of
        ok ->
            <<"Success">>;
        {error, timeout} ->
            <<"Timeout">>;
        {error, {producer_down, Reason}} ->
            ?LOG_DEBUG("Producer down: ~p", [Reason]),
            <<"Internal Error">>
    end,
    ?LOG_DEBUG("Reply ~s", [Reply]),
    {reply, {text, Reply}, State};
websocket_handle(InFrame, State) ->
    ?LOG_DEBUG("In frame: ~p", [InFrame]),
    {ok, State}.

websocket_info(ping, State) ->
    User = proplists:get_value(user, State),
    ?LOG_DEBUG("User ~p: ping", [User]),
    {reply, ping, State};
websocket_info(Info, State) ->
    ?LOG_DEBUG("Info: ~p", [Info]),
    {ok, State}.

terminate(Reason, _PartialReq, State) ->
    ?LOG_DEBUG("Terminateion reason: ~p", [Reason]),
    case proplists:get_value(ping_timer, State, no_timer) of
        no_timer ->
            ?LOG_ERROR("There is no heartbeat timer: ~p", [State]);
        PingTimer ->
            timer:cancel(PingTimer)
    end.

produce(User, Message) ->
    brod:produce_sync(kafka_client, topic(),
        _Partition = 0,
        _Key       = User,
        _Value     = Message
    ).

%% This process works within ranch application
jwt_key() ->
    {ok, JwtKey} = application:get_env(miniature_engine, jwt_key),
    JwtKey.

user_claim_key() ->
    {ok, Key} = application:get_env(miniature_engine, user_claim_key),
    Key.

topic() ->
    {ok, Topic} = application:get_env(miniature_engine, kafka_producer_topic),
    Topic.
