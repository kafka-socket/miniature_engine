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
    brod:start_link_topic_subscriber(kafka_client, topic(), config(), ?MODULE, []).

init(Topic, _InitArgs) ->
    ?LOG_DEBUG("~s:init(~p, [])", [?MODULE, Topic]),
    {ok, _CommittedOffsets = [], State = #state{} }.

handle_message(_Partition, #kafka_message{key=K, value = V, headers = H} = Message, State) ->
    ?LOG_DEBUG("Message received ~p", [Message]),
    ?LOG_DEBUG("Headers~p~nKey:~p~nValue: ~p", [H, V]),
    {ok, ack, State}.

topic() ->
    {ok, Topic} = application:get_env(kafka_consumer_topic),
    Topic.

config() ->
    [].
