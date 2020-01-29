-module(miniature_engine_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("brod/include/brod.hrl").

-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    connections_exceed_limit/1
]).

-export([
    full_cycle/1
]).

-define(USER_UUID, <<"qqq123">>).

all() ->
    [full_cycle, connections_exceed_limit].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(miniature_engine),
    {ok, _} = application:ensure_all_started(gun),
    ok = brod:start_client([{"localhost", 9092}], test_client, [
        {auto_start_producers, true}
    ]),
    DataDir = ?config(data_dir, Config),
    {ok, Token} = token(DataDir),
    [{token, Token} | Config].

end_per_suite(_Config) ->
    ok.

full_cycle(Config) ->
    Token = ?config(token, Config),
    {ok, ConnPid, StreamRef} = start_websockets(Token),
    {ok, SubscriberPid} = start_subscriber(),
    {ok, #kafka_message{key = ?USER_UUID, headers = Headers1}} = wait_kafka_message(),
    ?assertEqual(<<"init">>, proplists:get_value(<<"type">>, Headers1)),
    send_ws_message(ConnPid, "Hello!"),
    {ok, #kafka_message{key = ?USER_UUID, value = <<"Hello!">>}} = wait_kafka_message(),
    ok = send_kafka_message(<<"wazzup">>),
    {text, Message} = wait_ws_message(ConnPid, StreamRef),
    ?assertEqual(<<"wazzup">>, Message),
    ok = close_websockets(ConnPid),
    {ok, #kafka_message{key = ?USER_UUID, headers = Headers2}} = wait_kafka_message(),
    ?assertEqual(<<"terminate">>, proplists:get_value(<<"type">>, Headers2)),
    ok = brod_topic_subscriber:stop(SubscriberPid).

connections_exceed_limit(Config) ->
    Token = ?config(token, Config),
    {ok, ConnPid1, _} = start_websockets(Token),

    {error, _, Error} = start_websockets(Token),
    ?assertEqual(429, Error),

    ok = close_websockets(ConnPid1).

start_websockets(Token) ->
    {ok, ConnPid} = gun:open("localhost", 3030),
    {ok, http} = gun:await_up(ConnPid),
    StreamRef = gun:ws_upgrade(ConnPid, "/ws", [
        {<<"authorization">>, <<"Bearer ", Token/binary>>}
    ]),
    case wait_upgrade(ConnPid, StreamRef) of
        {ok} -> {ok, ConnPid, StreamRef};
        {error, {_, _, _, _, ErrorCode, _}} -> {error, ConnPid, ErrorCode}
    end.

wait_upgrade(ConnPid, StreamRef) ->
    receive
        {gun_upgrade, ConnPid, StreamRef, [<<"websocket">>], _Headers} ->
            {ok};
        Unexpected ->
            {error, Unexpected}
    after 1000 ->
        timeout
    end.

close_websockets(ConnPid) ->
    gun:close(ConnPid).

start_subscriber() ->
    brod_topic_subscriber:start_link(test_client, <<"ws-to-kafka">>,
        _Partitions = all,
        _ConsumerConfig = [],
        _CommittedOffsets = [],
        _MessageType = message,
        _CbFun = fun handle_kafka_message/3,
        _CbInitialState = #{pid => self()}
    ).

wait_kafka_message() ->
    receive
        {message, Message} ->
            {ok, Message};
        Unexpected ->
            ?debugVal(Unexpected),
            unexpected
    after 10000 ->
        timeout
    end.

wait_ws_message(ConnPid, StreamRef) ->
    receive
        {gun_ws, ConnPid, StreamRef, Frame} ->
            Frame
    after 1000 ->
        timeout
    end.

send_kafka_message(Message) ->
    send_kafka_message(Message, ?USER_UUID).

send_kafka_message(Message, User) ->
    brod:produce_sync(test_client, <<"kafka-to-ws">>,
        _Partition = 0,
        _Key       = User,
        _Value     = Message
    ).

send_ws_message(ConnPid, Message) ->
    gun:ws_send(ConnPid, {text, Message}).

token(Dir) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "ecdsa_private.pem")),
    [_EcpkParameters, ECPrivateKey] = public_key:pem_decode(Pem),
    Key = public_key:pem_entry_decode(ECPrivateKey),
    jwt:encode(<<"ES256">>, #{user_uid => ?USER_UUID}, Key).

handle_kafka_message(_Partition, Message, #{pid := Pid} = State) ->
    Pid ! {message, Message},
    {ok, ack, State}.
