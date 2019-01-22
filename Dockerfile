FROM erlang:21.2.3

ARG app_name=miniature_engine

RUN mkdir -p /srv && \
    mkdir -p /buildroot

WORKDIR /buildroot

COPY . .

RUN rebar3 release && \
    cp -r _build/default/rel/$app_name /srv

WORKDIR /srv/$app_name

CMD ["./bin/miniature_engine", "foreground"]
