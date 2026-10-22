#!/usr/bin/env bash
set -e

echo "Running architectural layer and lint check..."
dart run tool/check_layers.dart
