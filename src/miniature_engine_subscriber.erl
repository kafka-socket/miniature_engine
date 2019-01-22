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

start_link() ->
    brod:start_link_topic_subscriber(miniature_engine_consumer, topic(), config(), ?MODULE, []).

init(Topic, _InitArgs) ->
    ?LOG_DEBUG("~s:init(~p, [])", [?MODULE, Topic]),
    {ok, _CommittedOffsets = [], _State = #state{} }.

handle_message(_Partition, #kafka_message{key=K, value = V, headers = H}, State) ->
    ?LOG_DEBUG("Headers: ~p~nKey: ~p~nValue: ~p", [H, K, V]),
    bcast(K, V),
    {ok, ack, State};
handle_message(_Partition, Message, State) ->
    ?LOG_DEBUG("handle_message(~p)", [Message]),
    {ok, ack, State}.

bcast(<<>>, Message) ->
    ?LOG_ERROR("Empty user for message ~p", [Message]);
bcast(User, Message) ->
    [Pid ! {message, Message} || Pid <- miniature_engine_channels:by_key(User)].

topic() ->
    {ok, Topic} = application:get_env(kafka_consumer_topic),
    Topic.

config() ->
    [].
