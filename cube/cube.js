// Cube.js configuration — The Meridian Post semantic layer.
//
// Warehouse credentials are supplied via environment variables (see
// .env.example); nothing secret lives in this repo. The Postgres connection
// is derived automatically from the CUBEJS_DB_* variables.
//
// No Cube Store: the demo dataset (~205k events, marts ≤ 42k rows) answers
// queries comfortably on direct scans of Neon's smallest compute, so the
// cache/queue driver stays in-process memory (CUBEJS_CACHE_AND_QUEUE_DRIVER
// defaults and no pre-aggregations are defined). Add rollups here when query
// volume demands them — until then there is nothing for Cube Store to do.
module.exports = {
  schemaPath: 'model',
};