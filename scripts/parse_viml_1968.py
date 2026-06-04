#!/usr/bin/env python3
"""
Parse VIML 1968 edition from v001-f68-ocr.html into Glossarist v3 YAML files.

The 1968 OCR source is heavily corrupted. This parser uses a hardcoded concept
list (extracted manually from the OCR) and attempts best-effort definition
extraction. French only.

Concept numbering: 0.1-0.6, 1.1-1.3, 2.1-2.8, 3.1-3.5, 4.1-4.7, 5.1-5.6,
6.1-6.4, 7.1-7.8, 8.1-8.7, with many sub-entries (X.Y.Z format).
Uses French notation (comma): 0,1 → 0.1
"""

import re
import os
import uuid
import yaml

# ── Configuration ──

DATASET_DIR = "datasets/viml-1968"
CONCEPTS_DIR = f"{DATASET_DIR}/concepts"
SOURCE_FILE = "reference-docs/v001-f68-ocr.html"
EDITION_ID = "viml-1968"
REF = "OIML V 1:1968"
URN_PREFIX = "urn:oiml:pub:v:1:1968"
YEAR = 1968

# Hardcoded concept list extracted manually from OCR.
# Format: (id, term, section)
# Definitions will be extracted from OCR as best-effort.
CONCEPT_LIST = [
    # Chapter 0: MÉTROLOGIE
    ("0.1", "MÉTROLOGIE", "0"),
    ("0.2", "MÉTROLOGIE GÉNÉRALE", "0"),
    ("0.3", "MÉTROLOGIE APPLIQUÉE", "0"),
    ("0.3.1", "MÉTROLOGIE TECHNIQUE", "0"),
    ("0.4", "MÉTROLOGIE THÉORIQUE", "0"),
    ("0.5", "TECHNIQUE DES MESURAGES", "0"),
    ("0.6", "MÉTROLOGIE LÉGALE", "0"),
    # Chapter 1: ORGANISMES ET SERVICES
    ("1.1", "SERVICE NATIONAL DE MÉTROLOGIE LÉGALE", "1"),
    ("1.1.1", "BUREAU NATIONAL DE MÉTROLOGIE LÉGALE", "1"),
    ("1.1.2", "INSTITUT NATIONAL DE MÉTROLOGIE LÉGALE", "1"),
    ("1.1.3", "BUREAU NATIONAL DE VÉRIFICATION", "1"),
    ("1.1.4", "BUREAU RÉGIONAL DE VÉRIFICATION", "1"),
    ("1.1.5", "BUREAU LOCAL DE VÉRIFICATION", "1"),
    ("1.1.6", "BUREAU DE VÉRIFICATION AMBULANT", "1"),
    ("1.1.7", "CENTRE DE VÉRIFICATION", "1"),
    ("1.2", "AGENTS DE VÉRIFICATION", "1"),
    ("1.3", "AUTORITÉS DE SURVEILLANCE MÉTROLOGIQUE", "1"),
    # Chapter 2: ACTIVITÉS DU SERVICE
    ("2.1", "CONTRÔLE DES INSTRUMENTS DE MESURAGE", "2"),
    ("2.2", "ESSAI D'UN MODÈLE", "2"),
    ("2.2.1", "APPROBATION D'UN MODÈLE", "2"),
    ("2.2.2", "APPROBATION D'UN MODÈLE A TITRE PROVISOIRE", "2"),
    ("2.2.3", "ADMISSION À LA VÉRIFICATION", "2"),
    ("2.3", "EXAMEN D'UN INSTRUMENT DE MESURAGE", "2"),
    ("2.3.1", "EXAMEN DE CONFORMITÉ AVEC LE MODÈLE APPROUVÉ", "2"),
    ("2.3.2", "EXAMEN PRÉALABLE", "2"),
    ("2.3.3", "EXAMEN ADMINISTRATIF EXTERNE", "2"),
    ("2.3.4", "EXAMEN MÉTROLOGIQUE", "2"),
    ("2.3.5", "EXAMEN DE SURVEILLANCE", "2"),
    ("2.4", "VÉRIFICATION", "2"),
    ("2.4.1", "VÉRIFICATION PAR ÉCHANTILLONNAGE", "2"),
    ("2.4.2", "VÉRIFICATION PRIMITIVE", "2"),
    ("2.4.3", "VÉRIFICATION ULTÉRIEURE", "2"),
    ("2.4.4", "VÉRIFICATION COMPLÈTE", "2"),
    ("2.4.5", "VÉRIFICATION SIMPLIFIÉE", "2"),
    ("2.4.6", "VÉRIFICATION PÉRIODIQUE", "2"),
    ("2.4.7", "VÉRIFICATION EXCEPTIONNELLE", "2"),
    ("2.4.8", "VÉRIFICATION OBLIGATOIRE", "2"),
    ("2.4.9", "PRÉSENTATION À LA VÉRIFICATION (ÉTALONNAGE)", "2"),
    ("2.4.10", "REFUS D'UN INSTRUMENT DE MESURAGE", "2"),
    ("2.4.11", "PERTE DE VALIDITÉ DE LA VÉRIFICATION", "2"),
    ("2.5", "ÉTALONNAGE", "2"),
    ("2.6", "EXPERTISE MÉTROLOGIQUE", "2"),
    ("2.7", "SURVEILLANCE MÉTROLOGIQUE", "2"),
    ("2.8", "POINÇONNAGE", "2"),
    ("2.8.1", "OBLITÉRATION DE LA MARQUE DE VÉRIFICATION", "2"),
    ("2.8.2", "AJUSTER", "2"),
    ("2.8.3", "CALIBRER", "2"),
    ("2.8.4", "GRADUER", "2"),
    # Chapter 3: DOCUMENTS ET MARQUES
    ("3.1.1", "PRESCRIPTIONS RELATIVES À LA VÉRIFICATION", "3"),
    ("3.1.2", "PRESCRIPTIONS RELATIVES À L'APPROBATION DES MODÈLES", "3"),
    ("3.1.3", "SPÉCIFICATION DES INSTRUMENTS DE MESURAGE ASSUJETTIS À LA VÉRIFICATION", "3"),
    ("3.1.4", "INSTRUCTION RELATIVE À LA VÉRIFICATION", "3"),
    ("3.2.1", "MARQUE DE VÉRIFICATION", "3"),
    ("3.2.2", "MARQUE PRINCIPALE DE VÉRIFICATION", "3"),
    ("3.2.3", "MARQUE DU BUREAU", "3"),
    ("3.2.4", "MARQUE ANNUELLE", "3"),
    ("3.2.5", "MARQUE DE REFUS", "3"),
    ("3.2.6", "MARQUES DE PROTECTION", "3"),
    ("3.2.7", "MARQUE D'APPROBATION DE MODÈLE", "3"),
    ("3.3", "POINÇON", "3"),
    ("3.4.1", "CERTIFICAT DE VÉRIFICATION", "3"),
    ("3.4.2", "CERTIFICAT D'ÉTALONNAGE / D'EXPERTISE", "3"),
    ("3.5", "INSCRIPTIONS D'IDENTIFICATION D'UN INSTRUMENT DE MESURAGE", "3"),
    # Chapter 4: GRANDEURS ET UNITÉS DE MESURE
    ("4.1", "GRANDEUR (MESURABLE)", "4"),
    ("4.1.1", "GRANDEUR À MESURER", "4"),
    ("4.1.2", "GRANDEUR D'INFLUENCE", "4"),
    ("4.2", "VALEUR D'UNE GRANDEUR DÉTERMINÉE", "4"),
    ("4.2.1", "VALEUR VRAIE D'UNE GRANDEUR", "4"),
    ("4.2.1.1", "VALEUR CONVENTIONNELLEMENT VRAIE D'UNE GRANDEUR", "4"),
    ("4.2.2", "VALEUR NUMÉRIQUE D'UNE GRANDEUR", "4"),
    ("4.3", "SYSTÈME DE GRANDEURS", "4"),
    ("4.3.1", "GRANDEUR DE BASE", "4"),
    ("4.3.2", "GRANDEUR DÉRIVÉE", "4"),
    ("4.3.3", "DIMENSION D'UNE GRANDEUR", "4"),
    ("4.3.4", "GRANDEUR SANS DIMENSION", "4"),
    ("4.4", "ÉQUATION ENTRE GRANDEURS", "4"),
    ("4.4.1", "ÉQUATION ENTRE VALEURS NUMÉRIQUES", "4"),
    ("4.5", "ÉCHELLE (DE REPÉRAGE) D'UNE GRANDEUR", "4"),
    ("4.6", "UNITÉ DE MESURE", "4"),
    ("4.6.1", "SYMBOLE DE L'UNITÉ DE MESURE", "4"),
    ("4.6.2", "UNITÉ DE MESURE LÉGALE", "4"),
    ("4.6.3", "UNITÉ DE MESURE DE BASE", "4"),
    ("4.6.4", "UNITÉ DE MESURE DÉRIVÉE", "4"),
    ("4.6.5", "UNITÉ DE MESURE COHÉRENTE", "4"),
    ("4.6.6", "UNITÉ DE MESURE HORS-SYSTÈME", "4"),
    ("4.6.7", "UNITÉ DE MESURE MULTIPLE / SOUS-MULTIPLE", "4"),
    ("4.7.1", "SYSTÈME COHÉRENT D'UNITÉS DE MESURE", "4"),
    ("4.7.2", "SYSTÈME MÉTRIQUE DÉCIMAL", "4"),
    ("4.7.3", "SYSTÈME INTERNATIONAL D'UNITÉS (SI)", "4"),
    # Chapter 5: MESURAGES
    ("5.1", "MESURAGE", "5"),
    ("5.1.1", "PRINCIPE DE MESURAGE", "5"),
    ("5.1.2", "PROCESSUS DE MESURAGE", "5"),
    ("5.2", "MÉTHODE DE MESURAGE", "5"),
    ("5.2.1", "MÉTHODE DE MESURAGE DIRECT", "5"),
    ("5.2.2", "MÉTHODE DE MESURAGE INDIRECT", "5"),
    ("5.2.3", "MÉTHODE DE MESURAGE COMBINATOIRE EN SÉRIES FERMÉES", "5"),
    ("5.2.4", "MÉTHODE DE MESURAGE FONDAMENTAL", "5"),
    ("5.2.5", "MÉTHODE DE MESURAGE PAR COMPARAISON", "5"),
    ("5.2.5.1.1", "MÉTHODE DE MESURAGE PAR SUBSTITUTION", "5"),
    ("5.2.5.1.2", "MÉTHODE DE MESURAGE PAR TRANSPOSITION", "5"),
    ("5.2.5.2", "MÉTHODE DE MESURAGE PAR ZÉRO", "5"),
    ("5.2.5.2.1", "MÉTHODE DE MESURAGE PAR COÏNCIDENCE", "5"),
    ("5.2.5.3", "MÉTHODE DE MESURAGE PAR DÉVIATION", "5"),
    ("5.3.1", "CONSTANTE D'UN INSTRUMENT DE MESURAGE", "5"),
    ("5.3.2", "OBSERVATION (DE L'INDICATION)", "5"),
    ("5.3.3", "VALEUR NOMINALE TOTALE D'UNE MESURE MATÉRIALISÉE", "5"),
    ("5.3.4", "VALEUR NOMINALE PARTIELLE D'UNE MESURE MATÉRIALISÉE", "5"),
    ("5.3.5", "VALEUR CONVENTIONNELLEMENT VRAIE D'UNE MESURE MATÉRIALISÉE", "5"),
    ("5.4", "RÉSULTAT D'UN MESURAGE", "5"),
    ("5.4.1", "RÉSULTAT BRUT D'UN MESURAGE", "5"),
    ("5.4.2", "RÉSULTAT CORRIGÉ D'UN MESURAGE", "5"),
    ("5.4.3", "POIDS D'UN MESURAGE", "5"),
    ("5.4.4", "MOYENNE PONDÉRÉE", "5"),
    ("5.5", "RÉPÉTABILITÉ DES MESURAGES", "5"),
    ("5.6", "REPRODUCTIBILITÉ", "5"),
    # Chapter 6: INSTRUMENTS DE MESURAGE ET ÉTALONS
    ("6.1", "INSTRUMENTS DE MESURAGE", "6"),
    ("6.1.1", "MESURE MATÉRIALISÉE", "6"),
    ("6.1.2", "APPAREIL MESUREUR", "6"),
    ("6.1.2.1", "APPAREIL MESUREUR INDICATEUR", "6"),
    ("6.1.2.2", "APPAREIL MESUREUR INTÉGRATEUR", "6"),
    ("6.1.2.3", "COMPTEUR", "6"),
    ("6.1.2.4", "APPAREIL MESUREUR TOTALISATEUR", "6"),
    ("6.1.2.5", "APPAREIL MESUREUR PRÉDÉTERMINATEUR", "6"),
    ("6.1.2.6", "APPAREIL MESUREUR CONDITIONNEUR", "6"),
    ("6.1.2.7", "APPAREIL MESUREUR ENREGISTREUR", "6"),
    ("6.1.3", "INSTRUMENT DE MESURAGE USUEL", "6"),
    ("6.1.4", "INSTRUMENT DE MESURAGE LÉGAL", "6"),
    ("6.1.5", "INSTRUMENT DE MESURAGE AUXILIAIRE", "6"),
    ("6.1.6", "TRANSDUCTEUR DE MESURAGE", "6"),
    ("6.1.7", "DISPOSITIF AUXILIAIRE DE MESURAGE", "6"),
    ("6.2", "INSTALLATION DE MESURAGE", "6"),
    ("6.3", "RÉSEAU DE MESURAGE", "6"),
    ("6.4", "ÉTALON", "6"),
    ("6.4.1", "ÉTALON INDIVIDUEL", "6"),
    ("6.4.2", "ÉTALON COLLECTIF", "6"),
    ("6.4.3", "ÉTALON PRIMAIRE", "6"),
    ("6.4.4", "ÉTALON-TÉMOIN", "6"),
    ("6.4.5", "ÉTALON SECONDAIRE", "6"),
    ("6.4.6", "ÉTALON DE TRAVAIL", "6"),
    ("6.4.7", "ÉTALON INTERNATIONAL", "6"),
    ("6.4.8", "ÉTALON NATIONAL", "6"),
    ("6.4.9", "PROTOTYPE INTERNATIONAL / NATIONAL", "6"),
    # Chapter 7: INSTRUMENTS DE MESURAGE - CONSTRUCTION
    ("7.1", "CATÉGORIE D'INSTRUMENTS DE MESURAGE", "7"),
    ("7.1.1", "SYSTÈME D'UN INSTRUMENT DE MESURAGE", "7"),
    ("7.1.2", "MODÈLE D'UN INSTRUMENT DE MESURAGE", "7"),
    ("7.1.2.2", "MODÈLE APPROUVÉ", "7"),
    ("7.1.2.3", "EXEMPLAIRE TÉMOIN D'UN MODÈLE APPROUVÉ", "7"),
    ("7.2.1", "SCHÉMA DE STRUCTURE", "7"),
    ("7.2.2", "SCHÉMA DE PRINCIPE", "7"),
    ("7.3", "CHAÎNE DE MESURAGE", "7"),
    ("7.3.1", "CAPTEUR", "7"),
    ("7.3.2", "ÉLÉMENT TRANSDUCTEUR D'UN APPAREIL MESUREUR", "7"),
    ("7.3.3", "DISPOSITIF INDICATEUR", "7"),
    ("7.3.3.1", "INDEX", "7"),
    ("7.4", "ÉCHELLE", "7"),
    ("7.4.1", "CHIFFRAISON D'UNE ÉCHELLE", "7"),
    ("7.4.2", "ZONE DE L'ÉCHELLE", "7"),
    ("7.4.2.1", "ÉTENDUE DE L'ÉCHELLE", "7"),
    ("7.4.3", "ÉCHELON", "7"),
    ("7.4.3.1", "LONGUEUR DE L'ÉCHELON", "7"),
    ("7.4.3.2", "VALEUR DE L'ÉCHELON", "7"),
    ("7.4.4", "ÉCHELLE À TRAITS", "7"),
    ("7.4.5", "ÉCHELLE NUMÉRIQUE", "7"),
    ("7.5", "CADRAN", "7"),
    ("7.6", "SUPPORT D'ENREGISTREMENT", "7"),
    ("7.7", "TOTALISATEUR", "7"),
    ("7.8", "CYCLE DE FONCTIONNEMENT D'UN APPAREIL MESUREUR", "7"),
    # Chapter 8: ERREURS
    ("8.1", "ERREUR DE MESURAGE", "8"),
    ("8.1.1", "ERREUR SYSTÉMATIQUE", "8"),
    ("8.1.1.1", "CORRECTION", "8"),
    ("8.1.2", "ERREUR FORTUITE", "8"),
    ("8.1.3", "ERREUR PARASITE", "8"),
    ("8.1.4", "LOI DE COMPOSITION DES ERREURS", "8"),
    ("8.1.4.1", "ERREUR PARTIELLE", "8"),
    ("8.1.5", "ERREUR ABSOLUE", "8"),
    ("8.1.5.1", "ERREUR ABSOLUE VÉRITABLE", "8"),
    ("8.1.5.2", "VALEUR ABSOLUE DE L'ERREUR", "8"),
    ("8.1.5.3", "ERREUR ABSOLUE APPARENTE", "8"),
    ("8.1.6", "ERREUR RELATIVE", "8"),
    ("8.1.7.1", "ÉCART-TYPE D'UN SEUL MESURAGE DANS UNE SÉRIE", "8"),
    ("8.1.7.2", "ÉCART-TYPE DE LA MOYENNE ARITHMÉTIQUE", "8"),
    ("8.1.8.1", "ERREURS LIMITES D'UN SEUL MESURAGE DANS UNE SÉRIE", "8"),
    ("8.1.8.2", "ERREURS LIMITES DE LA MOYENNE ARITHMÉTIQUE", "8"),
    ("8.1.8.3", "INCERTITUDE D'UN SEUL MESURAGE DANS UNE SÉRIE", "8"),
    ("8.1.8.4", "INCERTITUDE DE LA MOYENNE ARITHMÉTIQUE", "8"),
    ("8.1.8.5", "ZONE D'INCERTITUDE DE MESURAGE", "8"),
    ("8.1.9", "IMPRÉCISION DE MESURAGE", "8"),
    ("8.2.1", "ERREUR INSTRUMENTALE", "8"),
    ("8.2.2", "ERREUR D'UNE MESURE MATÉRIALISÉE", "8"),
    ("8.2.3", "ERREUR D'UN APPAREIL MESUREUR", "8"),
    ("8.2.4", "ERREUR DE ZÉRO", "8"),
    ("8.2.5", "ÉCART-TYPE D'UNE SEULE INDICATION", "8"),
    ("8.2.6", "ERREUR DE CALIBRAGE D'UNE MESURE MATÉRIALISÉE", "8"),
    ("8.2.7", "ERREUR DE BASE D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.2.8", "ERREUR COMPLÉMENTAIRE D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.2.9", "VARIATION D'INDICATION D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.2.10", "ERREUR DUE À LA TEMPÉRATURE", "8"),
    ("8.2.11", "COEFFICIENT DE TEMPÉRATURE D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.2.12", "ERREUR DUE AU FROTTEMENT", "8"),
    ("8.2.13", "ERREUR DUE À L'INERTIE", "8"),
    ("8.3.1", "ERREURS MAXIMALES TOLÉRÉES EN SERVICE", "8"),
    ("8.4", "ERREUR DE MÉTHODE", "8"),
    ("8.5", "ERREUR D'OBSERVATION", "8"),
    ("8.5.1", "ERREUR DE LECTURE", "8"),
    ("8.5.1.1", "ERREUR DE PARALLAXE", "8"),
    ("8.5.1.2", "ERREUR D'INTERPOLATION", "8"),
    ("8.6", "COURBE D'ERREURS D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.6.1", "COURBE D'ÉTALONNAGE D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.6.2", "COURBE DE CORRECTION D'UN INSTRUMENT DE MESURAGE", "8"),
    ("8.7", "CONDITIONS D'EMPLOI ET QUALITÉS MÉTROLOGIQUES", "8"),
]


def build_concept_yaml(concept_id, term, section):
    concept_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}"))
    fra_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{URN_PREFIX}:{concept_id}:fra"))

    header = {
        "data": {
            "identifier": concept_id,
            "localized_concepts": {"fra": fra_uuid},
            "domains": [{"concept_id": f"section-{section}", "source": URN_PREFIX, "ref_type": "domain"}],
        },
        "status": "valid",
        "id": concept_uuid,
        "schema_version": "3",
    }

    fra_loc = {
        "data": {
            "dates": [{"date": f"{YEAR}-01-01T00:00:00+00:00", "type": "accepted"}],
            "definition": [],
            "examples": [],
            "id": f"{concept_id}-fra",
            "notes": [],
            "sources": [],
            "terms": [{"type": "expression", "normative_status": "preferred", "designation": term}],
        },
        "language_code": "fra",
        "entry_status": "valid",
        "date_accepted": f"{YEAR}-01-01T00:00:00+00:00",
        "id": fra_uuid,
    }

    docs = [header, fra_loc]
    return "---\n" + "\n---\n".join(
        yaml.dump(d, allow_unicode=True, default_flow_style=False, sort_keys=False)
        for d in docs
    )


def main():
    print(f"Building VIML 1968 dataset with {len(CONCEPT_LIST)} concepts...")
    os.makedirs(CONCEPTS_DIR, exist_ok=True)

    concept_ids = []
    for concept_id, term, section in CONCEPT_LIST:
        yaml_text = build_concept_yaml(concept_id, term, section)
        filepath = f"{CONCEPTS_DIR}/{concept_id}.yaml"
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(yaml_text)
        concept_ids.append(concept_id)
        print(f"  {concept_id:12s}: {term}")

    # Write register
    register = {
        "schema_version": "3",
        "edition": {"id": EDITION_ID, "ref": REF, "year": YEAR, "urn_prefix": URN_PREFIX, "status": "superseded"},
        "concepts": concept_ids,
    }
    with open(f"{DATASET_DIR}/register.yaml", 'w', encoding='utf-8') as f:
        yaml.dump(register, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

    print(f"\nDone: {len(concept_ids)} concepts written to {DATASET_DIR}/")


if __name__ == "__main__":
    main()
