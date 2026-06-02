<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useUiStore } from '../stores/ui';
import { useVocabularyStore } from '../stores/vocabulary';
import { ref, watch, onMounted, nextTick } from 'vue';
import type { SearchHit } from '../adapters/types';
import { useI18n } from '../i18n';
import SearchResults from './SearchResults.vue';

const router = useRouter();
const ui = useUiStore();
const store = useVocabularyStore();
const { t } = useI18n();
const query = ref('');
const results = ref<SearchHit[]>([]);
const searched = ref(false);
const selectedIdx = ref(-1);
const loading = ref(false);
const searchError = ref<string | null>(null);
const searchInputEl = ref<HTMLInputElement | null>(null);
let debounceTimer: ReturnType<typeof setTimeout> | null = null;

async function doSearch() {
  const q = query.value.trim();
  if (!q) return;
  ui.searchQuery = q;
  loading.value = true;
  searchError.value = null;
  try {
    results.value = await store.searchAcrossDatasets(q);
  } catch (e: any) {
    searchError.value = e.message || 'Search failed';
  } finally {
    loading.value = false;
  }
  searched.value = true;
  selectedIdx.value = -1;
  router.replace({ query: { q } });
}

function onInput() {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(async () => {
    const q = query.value.trim();
    if (q.length >= 2) {
      await doSearch();
    } else if (q.length === 0) {
      results.value = [];
      searched.value = false;
      selectedIdx.value = -1;
    }
  }, 300);
}

function clearSearch() {
  query.value = '';
  results.value = [];
  searched.value = false;
  selectedIdx.value = -1;
  router.replace({ query: {} });
}

// Group results by dataset
interface GroupedResults {
  registerId: string;
  title: string;
  style: { light: string; dark: string; color: string };
  hits: SearchHit[];
}

const groupedResults = computed(() => {
  const capped = results.value.slice(0, 100);
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

// Flatten for keyboard navigation
const flatHits = computed(() => groupedResults.value.flatMap(g => g.hits));
const hitIndexMap = computed(() => {
  const map = new Map<SearchHit, number>();
  flatHits.value.forEach((hit, i) => map.set(hit, i));
  return map;
});

function goToHit(hit: SearchHit) {
  router.push({
    name: 'concept',
    params: { registerId: hit.registerId, conceptId: hit.conceptId },
  });
}

function onKeydown(e: KeyboardEvent) {
  if (!searched.value || flatHits.value.length === 0) return;

  if (e.key === 'ArrowDown') {
    e.preventDefault();
    selectedIdx.value = Math.min(selectedIdx.value + 1, flatHits.value.length - 1);
    scrollToSelected();
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    selectedIdx.value = Math.max(selectedIdx.value - 1, -1);
    scrollToSelected();
  } else if (e.key === 'Enter' && selectedIdx.value >= 0) {
    e.preventDefault();
    goToHit(flatHits.value[selectedIdx.value]);
  }
}

function scrollToSelected() {
  nextTick(() => {
    document.querySelector<HTMLElement>('.search-hit-selected')?.scrollIntoView({ block: 'nearest' });
  });
}

// Sync with UI store search query
watch(() => ui.searchQuery, (q) => {
  if (q && q !== query.value) {
    query.value = q;
    doSearch();
  }
});

onMounted(() => {
  if (ui.searchQuery) {
    query.value = ui.searchQuery;
    doSearch();
  }
});
</script>

<template>
  <div class="max-w-2xl mx-auto px-0">
    <form @submit.prevent="doSearch" class="mb-6 sm:mb-8">
      <div class="flex gap-2">
        <div class="relative flex-1">
          <input
            ref="searchInputEl"
            v-model="query"
            @input="onInput"
            @keydown="onKeydown"
            type="text"
            placeholder="Search terms across all datasets..."
            class="w-full pl-9 pr-8 py-2.5 text-sm bg-surface border border-ink-100 rounded-lg focus:ring-2 focus:ring-ink-200 focus:border-ink-400 outline-none placeholder:text-ink-300 transition-all"
            autofocus
          />
          <svg v-if="!loading" class="absolute left-3 top-3 w-4 h-4 text-ink-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
          </svg>
          <svg v-else class="absolute left-3 top-3 w-4 h-4 text-ink-400 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <button
            v-if="query"
            @click="clearSearch"
            type="button"
            class="absolute right-2.5 top-2.5 text-ink-300 hover:text-ink-600 transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
        <button type="submit" class="btn-primary" :disabled="loading">{{ t('search.button') }}</button>
      </div>
    </form>

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
        <button @click="doSearch" class="btn-primary">{{ t('search.retry') }}</button>
      </div>
    </div>

    <div v-else-if="searched">
      <p class="text-sm text-ink-400 mb-4">{{ results.length === 1 ? t('search.oneResultFor', { query: ui.searchQuery }) : t('search.manyResultsFor', { count: String(results.length), query: ui.searchQuery }) }}</p>
      <div v-if="results.length === 0" class="text-center py-16">
        <div class="text-ink-200 text-5xl mb-4 font-serif">&empty;</div>
        <p class="text-ink-500 font-medium">{{ t('search.noResults') }}</p>
        <p class="text-sm text-ink-300 mt-1">{{ t('search.tryDifferent') }}</p>
      </div>

      <!-- Grouped results -->
      <div v-else class="space-y-6">
        <div v-for="group in groupedResults" :key="group.registerId">
          <!-- Dataset header -->
          <div class="flex items-center gap-2 mb-2">
            <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ backgroundColor: group.style.color }"></span>
            <span class="text-xs font-semibold text-ink-500 uppercase tracking-wide">{{ group.title }}</span>
            <span class="text-xs text-ink-300">{{ group.hits.length }} {{ group.hits.length === 1 ? t('search.result') : t('search.results') }}</span>
          </div>
          <!-- Hits -->
          <div class="space-y-1.5">
            <button
              v-for="hit in group.hits"
              :key="hit.conceptId + hit.language"
              @click="goToHit(hit)"
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
  </div>
</template>
