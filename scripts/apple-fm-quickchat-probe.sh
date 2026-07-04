#!/usr/bin/env bash
# Surface A Apple FM witness (Plan 1-MAS R5-P1). Re-runnable:
#   bash scripts/apple-fm-quickchat-probe.sh
# Asserts: FM available on this machine, a live streamed answer arrived via
# the cumulative-snapshot → delta pattern, and reports the guardrail-trip
# outcome honestly (triggered OR topic-passed — both are val