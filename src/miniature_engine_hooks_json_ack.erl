-module(miniature_engine_hooks_json_ack).

-include_lib("kernel/include/logger.hrl").

-behaviour(miniature_engine_hooks).

-export([
    on_message_received/3
]).

on_message_received(MessageText, KafkaResponse, State) ->
    case jsx:is_json(MessageText) of
        true ->
            send_ack(from_json(MessageText), KafkaResponse, State);
        false ->
            ?LOG_DEBUG("~p is not a JSON", [MessageText]),
            {ok, State}
    end.

send_ack(#{id := Id}, ok, State) ->
    {reply, {text, to_json(#{reply_to => Id, sent => true})}, State};
send_ack(#{id := Id}, {error, Error}, State) ->
    ?LOG_ERROR("Could not send a message due to kafka error ~p", [Error]),
    {reply, {text, to_json(#{reply_to => Id, sent => false})}, State};
send_ack(_DecodedMessage, _KafkaResponse, State) ->
    ?LOG_INFO("Message has inappropriate format"),
    {ok, State}.

from_json(MessageText) ->
    jsx:decode(MessageText, [return_maps, {labels, attempt_atom}]).

to_json(Term) ->
    jsx:encode(Term).
