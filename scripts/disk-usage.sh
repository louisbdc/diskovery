#\!/bin/bash

TARGET_DIR="${1:-.}"

echo "=========================================="
echo "  Disk Usage Analysis: $TARGET_DIR"
echo "=========================================="
echo ""

echo "--- Top 10 Largest Files ---"
echo ""
find "$TARGET_DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10
echo ""

echo "--- Top 10 Largest Directories ---"
echo ""
du -h "$TARGET_DIR" 2>/dev/null | sort -rh | head -11
echo ""

echo "--- Largest Directory ---"
echo ""
LARGEST=$(du -h "$TARGET_DIR" 2>/dev/null | sort -rh | head -1)
echo "$LARGEST"
echo ""
echo "=========================================="
