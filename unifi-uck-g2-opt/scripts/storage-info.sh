#!/bin/bash

echo "=== STORAGE CAPACITY REPORT ==="
echo ""

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$BASE_DIR/data"

echo "Location: $DATA_DIR"
echo ""

for dir in db-data unifi-config shared-storage; do
    if [ -d "$DATA_DIR/$dir" ]; then
        SIZE=$(du -sh "$DATA_DIR/$dir" 2>/dev/null | cut -f1)
        FILES=$(find "$DATA_DIR/$dir" -type f 2>/dev/null | wc -l)
        echo "$dir:"
        echo "  Size: $SIZE"
        echo "  Files: $FILES"
        echo "  Mount: rw (Read/Write)"
        echo ""
    fi
done

echo "Container Storage Limits:"
echo "  MongoDB: 2GB max"
echo "  UniFi:   3GB max"
echo "  vsftpd:  500MB max"
echo ""

AVAIL=$(df -h "$DATA_DIR" | tail -1 | awk '{print $4}')
echo "Host Available: $AVAIL"
echo "============================="
