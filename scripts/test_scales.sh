#!/bin/bash
niri msg -j outputs | jq -r 'to_entries[] | .key + ": " + (.value.logical.scale | tostring)'
