<script setup lang="ts">
import { computed } from 'vue';
import { useVocabularyStore } from '../stores/vocabulary';
import type { SearchHit } from '../adapters/types';
import { langName } from '../utils/lang';
import { useDsStyle } from '../utils/dataset-style';
import { useI18n } from '../i18n';

const props = defineProps<{
  loading: boolean;
  searchError: string | null;
  searched: boolean;
  searchQuery: string;
  results: SearchHit[];
  selectedIdx: number;
}>();

const emit = defineEmits<{
  retry: [];
  goHit: [hit: SearchHit];
}>();

const store = useVocabularyStore();
const { getStyle } = useDsStyle();
const { t } = useI18n();

interface GroupedResults {
  registerId: string;
  title: string;
  style: { light: string; dark: string; color: string };
  hits: SearchHit[];
}

const groupedResults = computed(() => {
  const capped = props.results.slice(0, 100);
  const map = new Map<string, SearchHit[]>();
  for (const hit of capped) {
    const group = map.get(hit.registerId) ?? [];
    group.push(hit);
    map.set(hit.registerId, group);
  }
  const groups: GroupedResults[] = [];
  for (const [registerId, hits] of map) {
    const m = store.manifests.get(registerId);
    groups.push({
      registerId,
      title: m?.title ?? registerId,
      style: getStyle(registerId),
      hits,
    });
  }
  return groups;
});

const flatHits = computed(() => groupedResults.value.flatMap(g => g.hits));
const hitIndexMap = computed(() => {
  const map = new Map<SearchHit, number>();
  flatHits.value.forEach((hit, i) => map.set(hit, i));
  return map;
});
</script>

<template>
  <div v-if="loading" class="text-center py-16">
    <svg class="w-8 h-8 text-ink-300 animate-spin mx-auto mb-4" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <p class="text-sm text-ink-400">{{ t('search.searching') }}</p>
  </div>

  <div v-else-if="searchError" class="text-center py-16">
    <div class="card p-8 border-red-200 bg-red-50/50 max-w-md mx-auto">
      <p class="text-red-700 font-medium mb-1">{{ t('search.failed') }}</p>
      <p class="text-sm text-red-600/80 mb-4">{{ searchError }}</p>
      <button @click="emit('retry')" class="btn-primary">{{ t('search.retry') }}</button>
    </div>
  </div>

  <div v-else-if="searched" class="search-results">
    <p class="text-sm text-ink-400 mb-4">{{ results.length === 1 ? t('search.oneResultFor', { query: searchQuery }) : t('search.manyResultsFor', { count: String(results.length), query: searchQuery }) }}</p>
    <div v-if="results.length === 0" class="text-center py-16">
      <div class="text-ink-200 text-5xl mb-4 font-serif">&empty;</div>
      <p class="text-ink-500 font-medium">{{ t('search.noResults') }}</p>
      <p class="text-sm text-ink-300 mt-1">{{ t('search.tryDifferent') }}</p>
    </div>

    <div v-else class="space-y-6">
      <div v-for="group in groupedResults" :key="group.registerId">
        <div class="flex items-center gap-2 mb-2">
          <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ backgroundColor: group.style.color }"></span>
          <span class="text-xs font-semibold text-ink-500 uppercase tracking-wide">{{ group.title }}</span>
          <span class="text-xs text-ink-300">{{ group.hits.length }} {{ group.hits.length === 1 ? t('search.result') : t('search.results') }}</span>
        </div>
        <div class="space-y-1.5">
          <button
            v-for="hit in group.hits"
            :key="hit.conceptId + hit.language"
            @click="emit('goHit', hit)"
            :class="selectedIdx === hitIndexMap.get(hit) ? 'bg-ink-50 border-ink-200 search-hit-selected' : ''"
            class="card-hover p-3 w-full text-left flex items-center justify-between group"
          >
            <div class="min-w-0">
              <span class="font-medium text-ink-800 group-hover:text-ink-900 transition-colors">{{ hit.designation }}</span>
              <span class="text-xs text-ink-300 ml-2 font-mono">{{ hit.conceptId }}</span>
              <span v-if="hit.snippet" class="block text-xs text-ink-300 mt-0.5 truncate">{{ hit.snippet }}</span>
            </div>
            <div class="flex items-center gap-2 flex-shrink-0">
              <span v-if="hit.matchField === 'id'" class="badge badge-gray text-[10px]">{{ t('search.idMatch') }}</span>
              <span class="text-xs font-semibold text-ink-500 bg-ink-50 px-1.5 py-0.5 rounded">{{ langName(hit.language) }}</span>
            </div>
          </button>
        </div>
      </div>
    </div>

    <div v-if="results.length > 100" class="text-center text-sm text-ink-300 mt-6 pt-4 border-t border-ink-100/60">
      {{ t('search.showingFirst', { max: '100', total: String(results.length) }) }}
    </div>
  </div>
</template>
