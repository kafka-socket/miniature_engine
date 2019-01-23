FROM erlang:21.2.3

RUN mkdir -p /buildroot

WORKDIR /buildroot

COPY . .

RUN rebar3 release

############################################################

FROM erlang:21.2.3

ARG app_name=miniature_engine

COPY --from=0 /buildroot/_build/default/rel/$app_name  /srv/$app_name

WORKDIR /srv/$app_name

CMD ["./bin/miniature_engine", "foreground"]
