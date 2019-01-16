-module(miniature_engine_hooks).

-include_lib("kernel/include/logger.hrl").

-export([on_message_received/3]).

%% See https://ninenines.eu/docs/en/cowboy/2.6/manual/cowboy_websocket/
%% for more details about cowboy websocket reply
-callback on_message_received(
    MessageText :: binary(),
    KafkaResponse :: ok | {error, any()},
    State :: list()
) -> {ok, State :: list()} | {reply, {text, ReplyMessage :: binary()}, State :: list()}.

on_message_received(_MessageText, KafkaResponse, State) ->
    case KafkaResponse of
        ok ->
            ?LOG_DEBUG("Message had been sent to kafka");
        {error, timeout} ->
            ?LOG_DEBUG("Timeout");
        {error, {producer_down, Reason}} ->
            ?LOG_DEBUG("Producer down: ~p", [Reason])
    end,
    {ok, State}.
