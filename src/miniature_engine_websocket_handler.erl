-module(miniature_engine_websocket_handler).

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
    io:format("Token is ~p~n", [Token]),
    {ok, #{<<"user_uid">> := User}} = jwt:decode(Token, ?JWT_KEY),
    {cowboy_websocket, Req, [{user, User}, {ua, Ua}] ++ State}.

websocket_init(State) ->
    User = proplists:get_value(user, State),
    true = gproc:reg({p, l, {user, User}}),
    {ok, TRef} = timer:send_interval(5000, self(), ping),
    {ok, [{ping_timer, TRef} | State]}.

websocket_handle(ping, State) ->
    io:format("ping received~n"),
    {reply, pong, State};
websocket_handle(pong, State) ->
    io:format("pong received~n"),
    {ok, State};
websocket_handle({text, Message}, State) ->
    io:format("Text message received ~p~n", [Message]),
    User = proplists:get_value(user, State),
    Reply = case produce(User, Message) of
        ok ->
            <<"Success">>;
        {error, timeout} ->
            <<"Timeout">>;
        {error, {producer_down, Reason}} ->
            io:format("Producer down: ~p~n", [Reason]),
            <<"Internal Error">>
    end,
    io:format("Reply ~s~n", [Reply]),
    {reply, {text, Reply}, State};
websocket_handle(InFrame, State) ->
    io:format("In frame: ~p~n", [InFrame]),
    {ok, State}.

websocket_info(ping, State) ->
    User = proplists:get_value(user, State),
    io:format("User ~p: ping~n", [User]),
    {reply, ping, State};
websocket_info(Info, State) ->
    io:format("Info: ~p~n", [Info]),
    {ok, State}.

terminate(Reason, _PartialReq, State) ->
    io:format("Terminateion reason: ~p~n", [Reason]),
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
