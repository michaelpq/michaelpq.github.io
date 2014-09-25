---
author: Michael Paquier
comments: true
lastmod: 2014-04-06
date: 2014-04-06 15:36:08+00:00
layout: post
type: post
slug: postgres-9-4-feature-highlight-indexing-jsonb
title: 'Postgres 9.4 feature highlight: Indexing JSON data with jsonb data type'
categories:
- PostgreSQL-2
tags:
- postgres
- postgresql
- 9.4
- open source
- database
- json
- jsonb
- gin
- gist
- operator
- function
- procedure
- data
- type
- storage
- document
- mongodb
---
PostgreSQL 9.4 is shipping with a new feature called [jsonb]
(http://www.postgresql.org/docs/devel/static/datatype-json.html), which is a
new data type able to store JSON data supporting GIN indexing (!). In short,
this feature, one of the most important of the upcoming release, if not the
most important, puts Postgres directly in good position in the field of
document-oriented database systems.

Since 9.2, an integrated [JSON datatype](/postgresql-2/postgres-9-2-highlight-json-data-type/)
already exists, completed with a set of functions ([data generation]
(/postgresql-2/postgres-9-3-feature-highlight-json-data-generation/)
and [parsing functions]
(/postgresql-2/postgres-9-3-feature-highlight-json-parsing-functions/))
as well as [operators]
(/postgresql-2/postgres-9-3-feature-highlight-json-operators/)
added in 9.3. When using "json" data type, data is stored as an exact
copy of the input text which functions working on it need to reparse causing
some processing overhead.

The new jsonb data type stores data in a decomposed binary format, so
inserting it is less performant than json because of the overhead necessary
to put it in shape but it is *faster* as it does not need reparsing, and
it has the advantage to support GIN indexing. For this last reason it is
actually recommended to use jsonb for your applications instead of json
(you might need only json depending on your needs though). Note as well
that jsonb has the same operators as functions as json, you can refer to
my previous posts on the matter to get some insight on them or directly at
the documentation of Postgres.

Now let's see how jsonb works and let's compare it with json with as data 
sample a dump of [geobase](http://www.geonames.org/export/), worth 8.6 million
tuples and 1.1GB, with many fields like the city name, country code (you can
refer to a complete list of the fields [here]
(http://download.geonames.org/export/dump/readme.txt)). After storing the
data into a new table with a raw COPY, let's transform it into json/jsonb
in a set of tables with a fillfactor at 100 to see how much space they use:

    =# COPY geodata FROM '$HOME/Downloads/allCountries.txt';
    COPY 8647839
    =# CREATE TABLE geodata_jsonb (data jsonb) with (fillfactor=100);
    CREATE TABLE
    =# CREATE TABLE geodata_json (data json) with (fillfactor=100);
    CREATE TABLE
    =# \timing
    Timing is on.
    =# INSERT INTO geodata_json SELECT row_to_json(geodata) FROM geodata;
    INSERT 0 8647839
    Time: 287158.457 ms
    =# INSERT INTO geodata_jsonb SELECT row_to_json(geodata)::jsonb FROM geodata;
    INSERT 0 8647839
    Time: 425825.967 ms

Inserting jsonb data took a little bit more time. And what is the difference
of size?

    =# SELECT pg_size_pretty(pg_relation_size('geodata_json'::regclass)) AS json,
              pg_size_pretty(pg_relation_size('geodata_jsonb'::regclass)) AS jsonb;
      json   |  jsonb  
    ---------+---------
     3274 MB | 3816 MB
    (1 row)

Creating indexes on json data is possible even with 9.3, for example by
indexing some given keys using the operators present (note that '->>' is
used as it returns text, and that the set of keys in the index is chosen
depending on the queries):

    =# CREATE INDEX geodata_index ON
        geodata_json ((data->>'country_code'), (data->>'asciiname'));
    CREATE INDEX
    =# SELECT pg_size_pretty(pg_relation_size('geodata_index'::regclass))
        AS json_index;
     json_index 
    ------------
     310 MB
    (1 row)
    =# SELECT (data->>'population')::int as population,
              data->'latitude' as latitude,
              data->'longitude' as longitude
       FROM geodata_json WHERE data->>'country_code' = 'JP' AND
            data->>'asciiname' = 'Tokyo' AND
            (data->>'population')::int != 0;
     population | latitude | longitude 
    ------------+----------+-----------
        8336599 | 35.6895  | 139.69171
    (1 row)
    =# -- Explain of previous query
                                                           QUERY PLAN                                                        
    -------------------------------------------------------------------------------------------------------------------------
     Bitmap Heap Scan on geodata_json  (cost=6.78..865.24 rows=215 width=32)
       Recheck Cond: (((data ->> 'country_code'::text) = 'JP'::text) AND ((data ->> 'asciiname'::text) = 'Tokyo'::text))
       Filter: (((data ->> 'population'::text))::integer <> 0)
       ->  Bitmap Index Scan on geodata_index  (cost=0.00..6.72 rows=216 width=0)
             Index Cond: (((data ->> 'country_code'::text) = 'JP'::text) AND ((data ->> 'asciiname'::text) = 'Tokyo'::text))
     Planning time: 0.172 ms
    (6 rows)

In this case the planner is able to use a bitmap index scan and uses the
index created previously.

Now one of the new things that jsonb has and not json is the possibility
to check containment within some data with the operator @>, which is indexable
using GIN, as well as the existence operators ?, ?| and ?& (to check if given
key(s) exist) by the way. GIN indexing is possible with two operator classes:

  * Default operator class that all four operators listed previously
  * jsonb_hash_ops, supporting only @> but performing better when searching
data and having a smaller on-disk size.

Here is how it works:

    =# CREATE INDEX geodata_gin ON geodata_jsonb
          USING GIN (data jsonb_hash_ops);
    CREATE INDEX
    =# SELECT (data->>'population')::int as population,
          data->'latitude' as latitude,
          data->'longitude' as longitude
       FROM geodata_jsonb WHERE data @> '{"country_code": "JP", "asciiname": "Tokyo"}' AND
           (data->>'population')::int != 0;
     population | latitude | longitude 
    ------------+----------+-----------
        8336599 | 35.6895  | 139.69171
    (1 row)
     =# SELECT pg_size_pretty(pg_relation_size('geodata_gin'::regclass)) AS jsonb_gin;
     jsonb_gin
    -----------
     1519 MB
    (1 row)
    =# -- EXPLAIN of previous query
                                         QUERY PLAN                                      
    -------------------------------------------------------------------------------------
     Bitmap Heap Scan on geodata_jsonb  (cost=131.01..31317.76 rows=8605 width=418)
       Recheck Cond: (data @> '{"asciiname": "Tokyo", "country_code": "JP"}'::jsonb)
       Filter: (((data ->> 'population'::text))::integer <> 0)
       ->  Bitmap Index Scan on geodata_gin  (cost=0.00..128.86 rows=8648 width=0)
             Index Cond: (data @> '{"asciiname": "Tokyo", "country_code": "JP"}'::jsonb)
      Planning time: 0.134 ms

Depending on the application needs, you might prefer a less space-consuming
index like a btree tree on the field names of the JSON data as showed
previously, the GIN indexing here having the advantage to be more generic as
it covers all the fields of JSON and checks their containment.
