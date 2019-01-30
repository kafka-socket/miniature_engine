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

init(Request, InitialState) ->
    State = maps:merge(maps:from_list(InitialState), #{request => Request}),
    Token = token(Request),
    ?LOG_DEBUG("Token is ~s", [Token]),
    case jwt:decode(Token, jwt_key()) of
        {ok, Decoded} ->
            User = maps:get(user_claim_key(), Decoded),
            {cowboy_websocket, Request, maps:merge(State, #{user => User})};
        {error, Error} ->
            ?LOG_ERROR("Bad token ~p", [Error]),
            {ok, cowboy_req:reply(401, Request), State}
    end.

websocket_init(State) ->
    User = proplists:get_value(user, State),
    miniature_engine_channels:register(User),
    produce(User, <<>>, "init"),
    {ok, TRef} = heartbeat(),
    {ok, maps:merge(State, #{heartbeat_timer => TRef})}.

websocket_handle(ping, State) ->
    ?LOG_DEBUG("ping received"),
    {reply, pong, State};
websocket_handle(pong, State) ->
    ?LOG_DEBUG("pong received"),
    {ok, State};
websocket_handle({text, Message}, State) ->
    ?LOG_DEBUG("Text message received ~p", [Message]),
    User = proplists:get_value(user, State),
    KafkaResponse = produce(User, Message, "text"),
    CbModule = cb_module(),
    CbModule:on_message_received(Message, KafkaResponse, State);
websocket_handle(InFrame, State) ->
    ?LOG_DEBUG("In frame: ~p", [InFrame]),
    {ok, State}.

websocket_info(stop_gracefully, State) ->
    {stop, State};
websocket_info(ping, State) ->
    User = proplists:get_value(user, State),
    ?LOG_DEBUG("User ~p: ping", [User]),
    {reply, ping, State};
websocket_info({message, Message}, State) ->
    ?LOG_DEBUG("websocket_info({message, ~p}, State)", [Message]),
    {reply, {text, Message}, State};
websocket_info(Info, State) ->
    ?LOG_DEBUG("Info: ~p", [Info]),
    {ok, State}.

terminate(Reason, _PartialReq, State) ->
    ?LOG_DEBUG("Termination reason: ~p", [Reason]),
    User = proplists:get_value(user, State),
    produce(User, <<>>, "terminate"),
    case maps:get(heartbeat_timer, State, no_timer) of
        no_timer ->
            ?LOG_ERROR("There is no heartbeat timer: ~p", [State]);
        Timer ->
            timer:cancel(Timer)
    end.

produce(undefined, _, _) ->
    ?LOG_ERROR("Undefined user"),
    {error, undefined_user};
produce(User, Message, Type) ->
    ?LOG_DEBUG("produce(~p, ~p, ~p)", [User, Message, Type]),
    KafkaMessage = #{
        key => User,
        value => Message,
        headers => [{"type", Type}]
    },
    brod:produce_sync(miniature_engine_producer, topic(),
        _Partition = 0,
        _Key       = User,
        _Value     = KafkaMessage
    ).

token(Request) ->
    Qs = cowboy_req:parse_qs(Request),
    case proplists:get_value(<<"token">>, Qs, no_token) of
        no_token ->
            token_from_header(Request);
        Token ->
            Token
    end.

token_from_header(Request) ->
    case cowboy_req:header(<<"authorization">>, Request) of
        <<"Bearer ", Token/binary>> ->
            Token;
        _ ->
            <<>>
    end.

heartbeat() ->
    timer:send_interval(heartbeat_interval(), self(), ping).

heartbeat_interval() ->
    application:get_env(miniature_engine, heartbeat_interval, 5000).

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

cb_module() ->
    application:get_env(miniature_engine, callback_module, miniature_engine_hooks).
