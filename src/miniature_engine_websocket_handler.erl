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

-type state() :: map().

-spec init(cowboy_req:req(), list()) -> {atom(), cowboy_req:req(), state()}.
init(Request, InitialState) ->
    State = maps:merge(maps:from_list(InitialState), #{request => Request}),
    Token = token(Request),
    case authenticate(Token) of
        {ok, User} ->
            Channels = miniature_engine_channels:by_key(User),
            case length(Channels) < channels_limit() of
                true ->
                    {cowboy_websocket, Request, maps:merge(State, #{user => User})};
                false ->
                    {ok, cowboy_req:reply(429, Request), State}
            end;
        {error, _} -> {ok, cowboy_req:reply(401, Request), State}
    end.

-spec websocket_init(state()) -> {ok, state()}.
websocket_init(#{user := User} = State) ->
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
    User = maps:get(user, State),
    KafkaResponse = produce(User, Message, "text"),
    CbModule = cb_module(),
    CbModule:on_message_received(Message, KafkaResponse, State);
websocket_handle(InFrame, State) ->
    ?LOG_DEBUG("In frame: ~p", [InFrame]),
    {ok, State}.

websocket_info(stop_gracefully, State) ->
    {stop, State};
websocket_info(ping, State) ->
    User = maps:get(user, State),
    ?LOG_DEBUG("User ~p: ping", [User]),
    {reply, ping, State};
websocket_info({message, Message}, State) ->
    ?LOG_DEBUG("websocket_info({message, ~p}, State)", [Message]),
    {reply, {text, Message}, State};
websocket_info(Info, State) ->
    ?LOG_DEBUG("Info: ~p", [Info]),
    {ok, State}.

terminate(Reason, _PartialReq, State) when is_map(State) ->
    ?LOG_DEBUG("Termination reason: ~p", [Reason]),
    User = maps:get(user, State),
    produce(User, <<>>, "terminate"),
    case maps:get(heartbeat_timer, State, no_timer) of
        no_timer ->
            ?LOG_ERROR("There is no heartbeat timer: ~p", [State]);
        Timer ->
            timer:cancel(Timer)
    end;
terminate(Reason, _PartialReq, _State) ->
    ?LOG_DEBUG("Termination reason: ~p", [Reason]).

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

    authenticate(Token) ->
        case jwt:decode(Token, jwt_key()) of
            {ok, Decoded} -> {ok, maps:get(user_claim_key(), Decoded)};
            {error, Error} -> {error, Error}
        end.


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

channels_limit() ->
    {ok, Limit} = application:get_env(miniature_engine, channels_limit_per_user),
    Limit.

cb_module() ->
    application:get_env(miniature_engine, callback_module, miniature_engine_hooks).

heartbeat_interval() ->
    application:get_env(miniature_engine, heartbeat_interval, 5000).

