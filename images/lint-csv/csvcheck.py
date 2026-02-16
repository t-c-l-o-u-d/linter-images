#!/usr/bin/env python3
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
"""Validate CSV structure: parse and check column consistency."""
import csv
import sys

path = sys.argv[1]
try:
    with open(path, newline="") as f:
        reader = csv.reader(f)
        expected = None
        for lineno, row in enumerate(reader, 1):
            if expected is None:
                expected = len(row)
            elif len(row) != expected:
                print(f"line {lineno}: expected {expected} columns, got {len(row)}")
                sys.exit(1)
except csv.Error as e:
    print(f"line {lineno}: {e}")
    sys.exit(1)
