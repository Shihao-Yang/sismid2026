#!/usr/bin/env bash
# Stop the SISMID Codex broker.
if pkill -f "[s]erve.py"; then
  echo "Broker stopped."
else
  echo "Broker was not running."
fi
