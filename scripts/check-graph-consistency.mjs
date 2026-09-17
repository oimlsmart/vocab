#!/usr/bin/env node
// Read-only post-build gate: the graph data the SPA loads must be
// internally consistent, or the Relations card degrades silently
// (incoming rows echo the current term, cross-dataset rows go dead).
//
// Checks, per dataset under dist/data/:
//   1. graph-nodes.json uriPrefix is a prefix of this dataset's
//      edges.json endpoint URIs (node designations must be findable
//      for every edge endpoint).
//   2. cross-ref-index.json lists a dataset pair whenever some other
//      dataset's edges.json targets it (undected cross-dataset edges
//      never load).
//
// Usage: node scripts/check-graph-consistency.mjs [dist-dir]

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const DIST = process.argv[2] ?? 'dist';
const DATA = join(DIST, 'data');

if (!existsSync(DATA)) {
  console.error(`check-graph-consistency: ${DATA} not found — run the build first`);
  process.exit(1);
}

const datasets = readdirSync(DATA).filter((name) =>
  existsSync(join(DATA, name, 'graph-nodes.json')),
);

if (datasets.length === 0) {
  console.error('check-graph-consistency: no datasets with graph-nodes.json found');
  process.exit(1);
}

const errors = [];

for (const ds of datasets) {
  const dir = join(DATA, ds);
  const graphNodes = JSON.parse(readFileSync(join(dir, 'graph-nodes.json'), 'utf8'));
  const prefix = graphNodes.uriPrefix ?? '';

  if (existsSync(join(dir, 'edges.json'))) {
    const edgesFile = JSON.parse(readFileSync(join(dir, 'edges.json'), 'utf8'));
    const edges = Array.isArray(edgesFile) ? edgesFile : (edgesFile.edges ?? []);
    const own = edges.filter((e) => e.source?.startsWith(prefix));
    if (own.length === 0) {
      errors.push(
        `${ds}: graph-nodes uriPrefix ${prefix} matches none of the ${edges.length} edges.json source URIs ` +
        '(node designations will not resolve; rows fall back to raw labels)',
      );
    }
  }

  const crossRefPath = join(DATA, 'cross-ref-index.json');
  if (existsSync(crossRefPath)) {
    const index = JSON.parse(readFileSync(crossRefPath, 'utf8'));
    // Any other dataset's edges targeting this one must be indexed.
    for (const other of datasets) {
      if (other === ds) continue;
      const edgesPath = join(DATA, other, 'edges.json');
      if (!existsSync(edgesPath)) continue;
      const otherFile = JSON.parse(readFileSync(edgesPath, 'utf8'));
      const edges = Array.isArray(otherFile) ? otherFile : (otherFile.edges ?? []);
      const targetsOtherToDs = edges.some((e) =>
        typeof e.target === 'string' && e.target.includes(`/${ds}/concept/`),
      );
      const listed = (index[ds] ?? []).includes(other);
      if (targetsOtherToDs && !listed) {
        errors.push(
          `cross-ref-index: ${other} -> ${ds} edges exist but ${ds} does not list ${other} ` +
          '(cross-dataset edges will not load)',
        );
      }
    }
  }
}

if (errors.length > 0) {
  console.error('check-graph-consistency: FAILED');
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`check-graph-consistency: OK (${datasets.length} datasets consistent)`);
