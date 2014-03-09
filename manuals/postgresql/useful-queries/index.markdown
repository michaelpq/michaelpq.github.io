---
author: Michael Paquier
date: 2014-03-09 14:14:18+00:00
layout: page
type: page
slug: useful-queries
title: PostgreSQL - Useful queries
tags:
- postgres
- postgresql
- performance
- bloat
- analysis
- query
- useful
- detection
- check
- recommendation
- advice
- tip
- trick
---
On this page are presented a set of queries that can be used for performance
analysis.

Detect the most bloated tables (no need of extensions):

    SELECT relname,
        seq_scan,
        idx_scan,
        n_live_tup,
        n_dead_tup,
        to_char(n_dead_tup/n_live_tup::real, '999D99')::real AS ratio,
        pg_size_pretty(pg_relation_size(relid))
    FROM pg_stat_all_tables
    WHERE pg_relation_size(relid) > 1024 * 1024 AND
        n_live_tup > 0
    ORDER BY n_dead_tup/n_live_tup::real DESC LIMIT 10;

List the unused indexes:

    SELECT
        schemaname || '.' || relname AS table,
        indexrelname AS index,
        pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
        idx_scan as index_scans
    FROM pg_stat_user_indexes ui
        JOIN pg_index i ON ui.indexrelid = i.indexrelid
    WHERE NOT indisunique AND idx_scan < 50 AND pg_relation_size(relid) > 1024 * 1024
    ORDER BY pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) DESC NULLS FIRST,
        pg_relation_size(i.indexrelid) DESC;
