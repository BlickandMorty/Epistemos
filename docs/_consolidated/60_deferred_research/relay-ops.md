# Relay Ops

> **Index status**: DEFERRED-RESEARCH — Phase K relay-ops design (channel infrastructure).
> **Phase**: Phase K Pro-only.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/`.



Epistemos now has a shared relay contract for remote channel delivery and inbound polling.

## Server

Run the relay server anywhere your connector can reach it:

```bash
epistemos_channel_relay --listen 0.0.0.0:8787
```

Optional environment:

```bash
export EPISTEMOS_CHANNEL_RELAY_DB="$HOME/.epistemos/channel_relay.db"
export EPISTEMOS_CHANNEL_RELAY_TOKEN="replace-me"
```

If you prefer CLI flags instead of env:

```bash
epistemos_channel_relay --listen 0.0.0.0:8787 --db "$HOME/.epistemos/channel_relay.db" --token "$EPISTEMOS_CHANNEL_RELAY_TOKEN"
```

## Workers

Run one worker per outbound connector channel:

```bash
epistemos_channel_worker --channel telegram --relay http://127.0.0.1:8787
epistemos_channel_worker --channel slack --relay http://127.0.0.1:8787
epistemos_channel_worker --channel discord --relay http://127.0.0.1:8787
epistemos_channel_worker --channel whatsapp --relay http://127.0.0.1:8787
epistemos_channel_worker --channel signal --relay http://127.0.0.1:8787
epistemos_channel_worker --channel email --relay http://127.0.0.1:8787
```

Optional flags:

```bash
--token "$EPISTEMOS_CHANNEL_RELAY_TOKEN"
--interval 5
--batch 20
--once
```

## Connector Env

- `telegram`: `TELEGRAM_BOT_TOKEN`
- `slack`: none if the webhook URL is stored in the channel route
- `discord`: none if the webhook URL is stored in the channel route
- `whatsapp`: `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, optional `WHATSAPP_API_VERSION`
- `signal`: `SIGNAL_CLI_BASE_URL`, `SIGNAL_ACCOUNT`
- `email`: `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM`, optional `SMTP_PORT`

## iMessage Note

`iMessage` does not use the generic connector worker. Keep using the native bridge, or pair the relay with your remote iMessage gateway / BlueBubbles-style bridge.

## Relay API

- `GET /healthz`
- `POST /v1/channels/:channel_id/inbound`
- `GET /v1/channels/:channel_id/messages/unread`
- `GET /v1/channels/:channel_id/threads`
- `GET /v1/channels/:channel_id/audit`
- `POST /v1/channels/:channel_id/messages`
- `GET /v1/channels/:channel_id/outbox`
- `POST /v1/channels/:channel_id/outbox/:outbox_id/ack`

## Release Reality

This relay stack is aimed at direct-distribution builds. It is not a path to Mac App Store compliance for the full Epistemos agent feature set.
