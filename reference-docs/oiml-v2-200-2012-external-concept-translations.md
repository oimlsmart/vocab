# OIML V 2-200:2012 — External concept translations (English ↔ French)

These parenthetical concepts appear in the OIML V 2-200:2012 concept
diagrams as external/parenthetic terms. This file is the canonical
English → French translation reference for the dataset.

When modeling these in Glossarist, use the `external: true` flag on
ConceptRef:

```yaml
members:
  - ref:
      text: "precision condition of measurement"
      external: true
```

For localized rendering, the adapter resolves the `text` against this
table to find the French equivalent.

## Translations

| English (source diagram) | French |
|---|---|
| (kind of property) | (nature de propriété) |
| (property) | (propriété) |
| (quantity expressed by a measurement unit) | (grandeur exprimée par une unité de mesure) |
| (reference) | (référence) |
| (in-system measurement unit) | (unité faisant partie du système) |
| (non-coherent derived unit) | (unité dérivée non cohérente) |
| (rule for use of measurement units) | (règle pour l'emploi des unités de mesure) |
| (CGS system of units) | (système d'unités CGS) |
| (other information) | (autre information) |
| (quantity being measured) | (grandeur mesurée) |
| (definition of a quantity) | (définition d'une grandeur) |
| (precision condition of measurement) | (condition de mesure relative à la fidélité) |
| (operator) | (opérateur) |
| (operating condition) | (condition de fonctionnement) |
| (location) | (lieu) |
| (replicate measurement) | (mesurage répété) |
| (duration) | (durée) |
| (evaluation of measurement uncertainty component) | (évaluation d'une composante de l'incertitude de mesure) |
| (requirement) | (exigence) |
| (element of a measuring system) | (élément d'un système de mesure) |
| (signal) | (signal) |
| (output element of a measuring system) | (élément de sortie d'un système de mesure) |
| (metrological property of a measuring instrument or measuring system) | (propriété métrologique d'un instrument de mesure ou d'un système de mesure) |
| (trueness control material) | (matériau de contrôle de la justesse) |
| (control material) | (matériau de contrôle) |
| (precision control material) | (matériau de contrôle de la fidélité) |
| (reference material certificate) | (certificat d'un matériau de référence) |

## Usage notes

- The parentheses in both columns are part of the ISO 704:2022
  parenthetic-term convention, not optional delimiters.
- When the English text appears in a concept diagram, the French
  equivalent should be used in the French localization of the same
  diagram.
- These are NOT formal concept definitions — they are parenthetical
  labels for concepts taken as primitives in the OIML analysis.
- If any of these later get formal definitions (via `status: external`
  ManagedConcept + `provided_by` resolution), the inline text-only
  ConceptRef can be upgraded to a `{source, id}` ref.
