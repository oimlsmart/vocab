<script setup lang="ts">
import type { Citation } from 'glossarist';
import { computed } from 'vue';
import { getFactory } from '../adapters/factory';
import { useRouter } from 'vue-router';
import { useVocabularyStore } from '../stores/vocabulary';

const props = defineProps<{
  citation: Citation;
  registerId?: string;
}>();

const router = useRouter();
const store = useVocabularyStore();
const factory = getFactory();

function formatRef(c: Citation): string {
  const ref = c.ref;
  if (!ref) return '';
  const parts: string[] = [];
  if (ref.source) parts.push(ref.source);
  if (ref.id) parts.push(ref.id);
  if (ref.version) parts.push(`(${ref.version})`);
  return parts.join(' ');
}

const sourceRefMapping: Record<string, string> = {
  'JCGM 200:2012': 'urn:jcgm:pub:200:2012',
  'OIML V2-200:2012': 'urn:jcgm:pub:200:2012',
};

function resolveSourceRef(citation: Citation): { registerId: string; conceptId: string } | null {
  const ref = citation.ref;
  const locality = citation.locality;
  if (!ref?.source || !locality?.referenceFrom) return null;

  const urn = sourceRefMapping[ref.source] || (ref.source.startsWith('urn:') ? ref.source : null);
  if (!urn) return null;

  const uri = `${urn}/${locality.referenceFrom}`;
  const resolution = factory.resolve(uri, props.registerId);
  if (resolution.type === 'internal') {
    return { registerId: resolution.registerId, conceptId: resolution.conceptId.replace(/^\//, '') };
  }

  const directUri = urn + locality.referenceFrom;
  const directRes = factory.resolve(directUri, props.registerId);
  if (directRes.type === 'internal') {
    return { registerId: directRes.registerId, conceptId: directRes.conceptId.replace(/^\//, '') };
  }

  return null;
}

const resolvedTarget = computed(() => resolveSourceRef(props.citation));

async function navigateSourceRef() {
  if (!resolvedTarget.value) return;
  const { registerId, conceptId } = resolvedTarget.value;
  await store.viewConcept(registerId, conceptId);
  router.push({ name: 'concept', params: { registerId, conceptId } });
}
</script>

<template>
  <span class="inline">
    <template v-if="citation.ref">
      <button v-if="resolvedTarget" @click="navigateSourceRef" class="concept-link font-medium">{{ citation.ref.source }}</button>
      <span v-else-if="citation.ref.source" class="font-medium">{{ citation.ref.source }}</span>
      <span v-if="citation.ref.id"> {{ citation.ref.id }}</span>
      <span v-if="citation.ref.version" class="text-ink-400"> ({{ citation.ref.version }})</span>
    </template>
    <template v-if="citation.locality">
      <button v-if="resolvedTarget" @click="navigateSourceRef" class="concept-link">
        <span v-if="citation.locality.type" class="text-ink-400">, {{ citation.locality.type }}</span>
        <span v-if="citation.locality.referenceFrom" class="text-ink-400">
          {{ citation.locality.referenceTo ? ` ${citation.locality.referenceFrom}–${citation.locality.referenceTo}` : ` ${citation.locality.referenceFrom}` }}
        </span>
      </button>
      <template v-else>
        <span v-if="citation.locality.type" class="text-ink-400">, {{ citation.locality.type }}</span>
        <span v-if="citation.locality.referenceFrom" class="text-ink-400">
          {{ citation.locality.referenceTo ? ` ${citation.locality.referenceFrom}–${citation.locality.referenceTo}` : ` ${citation.locality.referenceFrom}` }}
        </span>
      </template>
    </template>
    <a v-if="citation.link" :href="citation.link" target="_blank" rel="noopener" class="concept-link ml-1">[link]</a>
    <span v-if="citation.original" class="text-xs text-ink-300 ml-1">(orig: {{ citation.original }})</span>
    <span v-if="resolvedTarget" class="text-[9px] text-ink-300 ml-1">→ {{ resolvedTarget.registerId }}/{{ resolvedTarget.conceptId }}</span>
  </span>
</template>
