-module(miniature_engine_subscriber).

-include_lib("kernel/include/logger.hrl").
-include_lib("brod/include/brod.hrl").

-behaviour(brod_topic_subscriber).

-export([
    start_link/0
]).

-export([
    init/2,
    handle_message/3
]).

-record(state, {}).

-type state() :: #state{}.
-type committed_offsets() :: [{brod:partition(), brod:offset()}].

-spec start_link() -> {ok, pid()}.
start_link() ->
    ok = wait_for_topic(),
    brod:start_link_topic_subscriber(miniature_engine_consumer, topic(), config(), ?MODULE, []).

-spec init(binary(), any()) -> {ok, committed_offsets(), state()}.
init(Topic, _InitArgs) ->
    ?LOG_DEBUG("~s:init(~p, [])", [?MODULE, Topic]),
    {ok, _CommittedOffsets = [], _State = #state{}}.

-spec handle_message(non_neg_integer(), brod:message(), state()) -> {ok, ack, state()}.
handle_message(_Partition, #kafka_message{key=K, value = V, headers = H}, State) ->
    ?LOG_DEBUG("handle_message(~p, ~p)", [H, V]),
    bcast(K, V),
    {ok, ack, State};
handle_message(_Partition, Message, State) ->
    ?LOG_DEBUG("handle_message(~p)", [Message]),
    {ok, ack, State}.

bcast(<<>>, Message) ->
    ?LOG_ERROR("Empty user for message ~p", [Message]);
bcast(User, Message) ->
    [Pid ! {message, Message} || Pid <- miniature_engine_channels:by_key(User)].

wait_for_topic() ->
    wait_for_topic(brod_client:get_metadata(miniature_engine_consumer, topic())).

wait_for_topic({ok, #{topic_metadata := [#{error_code := no_error}]}}) ->
    ok;
wait_for_topic({ok, #{topic_metadata := [#{error_code := Error}]}}) ->
    ?LOG_ERROR("Topic ~s error: ~p", [topic(), Error]),
    timer:sleep(timer:seconds(2)),
    wait_for_topic();
wait_for_topic({error, Error}) ->
    ?LOG_ERROR("Topic ~s unavailable: ~p", [topic(), Error]),
    timer:sleep(timer:seconds(2)),
    wait_for_topic().

topic() ->
    {ok, Topic} = application:get_env(kafka_consumer_topic),
    Topic.

config() ->
    [].
