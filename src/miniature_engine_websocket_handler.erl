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

-define(JWT_KEY, <<"your-256-bit-secret">>).

init(Req, State) ->
    Qs = cowboy_req:parse_qs(Req),
    Ua = cowboy_req:header(<<"user-agent">>, Req),
    Token = proplists:get_value(<<"token">>, Qs),
    ?LOG_DEBUG("Token is ~p", [Token]),
    {ok, #{<<"user_uid">> := User}} = jwt:decode(Token, ?JWT_KEY),
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
    PingTimer = proplists:get_value(ping_timer, State),
    {ok, cancel} = timer:cancel(PingTimer),
    ok.

produce(User, Message) ->
    brod:produce_sync(
        _Client    = kafka_client,
        _Topic     = <<"my-topic">>,
        _Partition = 0,
        _Key       = User,
        _Value     = Message
    ).
