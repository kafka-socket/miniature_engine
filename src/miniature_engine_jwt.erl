%%
%% JWT Library for Erlang.
%% Written by Peter Hizalev at Kato (http://kato.im)
%% Rewritten by Yuri Artemev (http://artemff.com)
%%

-module (miniature_engine_jwt).

-export([decode/2, decode/3]).
-export([encode/3, encode/4]).

-define(HOUR, 3600).
-define(DAY, 3600 * 60).

%%
%% API
%%

encode(Alg, ClaimsSet, Key) ->
    Claims = base64url:encode(jsx:encode(ClaimsSet)),
    Header = base64url:encode(jsx:encode(jwt_header(Alg))),
    Payload = <<Header/binary, ".", Claims/binary>>,
    case jwt_sign(Alg, Payload, Key) of
        undefined -> {error, algorithm_not_supported};
        Signature -> {ok, <<Payload/binary, ".", Signature/binary>>}
    end.

encode(Alg, ClaimsSet, Expiration, Key) ->
    Claims = base64url:encode(jsx:encode(jwt_add_exp(ClaimsSet, Expiration))),
    Header = base64url:encode(jsx:encode(jwt_header(Alg))),
    Payload = <<Header/binary, ".", Claims/binary>>,
    case jwt_sign(Alg, Payload, Key) of
        undefined -> {error, algorithm_not_supported};
        Signature -> {ok, <<Payload/binary, ".", Signature/binary>>}
    end.

decode(Token, Key) ->
    case split_token(Token) of
        SplitToken = [Header, Claims | _] ->
            case decode_jwt(SplitToken) of
                {#{<<"alg">> := Alg} = _Header, ClaimsJSON, Signature} ->
                    case jwt_check_sig(Alg, Header, Claims, Signature, Key) of
                        false -> {error, invalid_signature};
                        true ->
                            case jwt_is_expired(ClaimsJSON) of
                                true  -> {error, expired};
                                false -> {ok, ClaimsJSON}
                            end
                    end;
                invalid -> {error, invalid_token}
            end;
        _ -> {error, invalid_token}
    end.

% When there are multiple issuers and keys are on a per issuer bases
% then apply those keys instead
decode(Token, DefaultKey, IssuerKeyMapping) ->
    case split_token(Token) of
        SplitToken = [Header, Claims | _] ->
            case decode_jwt(SplitToken) of
                {#{<<"alg">> := Alg} = _Header, ClaimsJSON, Signature} ->
                    Issuer = maps:get(<<"iss">>, ClaimsJSON, undefined),
                    Key = maps:get(Issuer, IssuerKeyMapping, DefaultKey),
                    case jwt_check_sig(Alg, Header, Claims, Signature, Key) of
                        false -> {error, invalid_signature};
                        true ->
                            case jwt_is_expired(ClaimsJSON) of
                                true  -> {error, expired};
                                false -> {ok, ClaimsJSON}
                            end
                    end;
                invalid -> {error, invalid_token}
            end;
        _ -> {error, invalid_token}
    end.



%%
%% Decoding helpers
%%

jsx_decode_safe(Bin) ->
    try
        jsx:decode(Bin, [return_maps])
    catch _ ->
        invalid
    end.

jwt_is_expired(#{<<"exp">> := Exp} = _ClaimsJSON) ->
    case (Exp - epoch()) of
        DeltaSecs when DeltaSecs > 0 -> false;
        _ -> true
    end;
jwt_is_expired(_) ->
    false.

jwt_check_sig(Alg, Header, Claims, Signature, Key) ->
    jwt_check_sig(algorithm_to_crypto(Alg), <<Header/binary, ".", Claims/binary>>, Signature, Key).

jwt_check_sig({hmac, _} = Alg, Payload, Signature, Key) ->
    jwt_sign_with_crypto(Alg, Payload, Key) =:= Signature;

jwt_check_sig({rsa, Crypto}, Payload, Signature, Key) ->
    public_key:verify(Payload, Crypto, base64url:decode(Signature), Key);

jwt_check_sig(_, _, _, _) ->
    false.


split_token(Token) ->
    binary:split(Token, <<".">>, [global]).

decode_jwt([Header, Claims, Signature]) ->
    try
        [HeaderJSON, ClaimsJSON] =
            Decoded = [jsx_decode_safe(base64url:decode(X)) || X <- [Header, Claims]],
        case lists:any(fun(E) -> E =:= invalid end, Decoded) of
            true  -> invalid;
            false -> {HeaderJSON, ClaimsJSON, Signature}
        end
    catch _:_ ->
        invalid
    end;
decode_jwt(_) ->
    invalid.

%%
%% Encoding helpers
%%

jwt_add_exp(ClaimsSet, Expiration) ->
    Exp = expiration_to_epoch(Expiration),
    append_claim(ClaimsSet, <<"exp">>, Exp).

jwt_header(Alg) ->
    [ {<<"alg">>, Alg}
    , {<<"typ">>, <<"JWT">>}
    ].

%%
%% Helpers
%%

jwt_sign(Alg, Payload, Key) ->
    jwt_sign_with_crypto(algorithm_to_crypto(Alg), Payload, Key).

jwt_sign_with_crypto({hmac, Crypto}, Payload, Key) ->
    base64url:encode(crypto:hmac(Crypto, Key, Payload));

jwt_sign_with_crypto({rsa,  Crypto}, Payload, Key) ->
    base64url:encode(public_key:sign(Payload, Crypto, Key));

jwt_sign_with_crypto(_, _Payload, _Key) ->
    undefined.

algorithm_to_crypto(<<"HS256">>) -> {hmac, sha256};
algorithm_to_crypto(<<"HS384">>) -> {hmac, sha384};
algorithm_to_crypto(<<"HS512">>) -> {hmac, sha512};
algorithm_to_crypto(<<"RS256">>) -> {rsa,  sha256};
algorithm_to_crypto(_)           -> undefined.

epoch() -> erlang:system_time(seconds).

expiration_to_epoch(Expiration) ->
    Ts = epoch(),
    case Expiration of
        {hourly, Expiration0} -> (Ts - (Ts rem ?HOUR)) + Expiration0;
        {daily, Expiration0} -> (Ts - (Ts rem ?DAY)) + Expiration0;
        _ -> epoch() + Expiration
    end.

append_claim(ClaimsSet, Key, Val) when is_map(ClaimsSet) ->
  ClaimsSet#{ Key => Val };
append_claim(ClaimsSet, Key, Val) -> [{ Key, Val } | ClaimsSet].
