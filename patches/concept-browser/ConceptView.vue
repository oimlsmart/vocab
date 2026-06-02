<script setup lang="ts">
import { computed, watch, ref, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useVocabularyStore } from '../stores/vocabulary';
import ConceptDetail from '../components/ConceptDetail.vue';
import { useI18n } from '../i18n';

const { t } = useI18n();

const props = defineProps<{
  registerId: string;
  conceptId: string;
}>();

const store = useVocabularyStore();
const router = useRouter();
const conceptLoading = ref(false);
const localError = ref<string | null>(null);
const showShortcuts = ref(false);

async function loadConcept(regId: string, cId: string) {
  conceptLoading.value = true;
  localError.value = null;
  store.error = null;
  try {
    // Ensure dataset is loaded (index + chunks) before fetching concept
    const adapter = store.datasets.get(regId);
    if (!adapter?.index) {
      await store.loadDataset(regId);
    }
    await store.viewConcept(regId, cId);
  } catch (e: any) {
    localError.value = e.message || 'Unknown error';
  } finally {
    conceptLoading.value = false;
  }
}

watch(
  () => [props.registerId, props.conceptId],
  async ([regId, cId]) => {
    await loadConcept(regId as string, cId as string);
    loadAdjacent();
  },
  { immediate: true }
);

const concept = computed(() => store.currentConcept);
const manifest = computed(() => store.currentManifest);
const edges = computed(() => store.conceptEdges);
const adjacent = ref({ prev: null as string | null, next: null as string | null });

async function loadAdjacent() {
  const adapter = store.datasets.get(props.registerId);
  if (!adapter?.index) return;
  const idx = adapter.getConceptPosition(props.conceptId);
  if (idx >= 0) {
    await adapter.ensureChunksForRange(Math.max(0, idx - 1), 3);
  }
  adjacent.value = adapter.getAdjacentConcepts(props.conceptId);
}

watch(() => props.conceptId, () => { loadAdjacent(); });

function goAdjacent(id: string) {
  router.push({ name: 'concept', params: { registerId: props.registerId, conceptId: id } });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function onKeydown(e: KeyboardEvent) {
  if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;

  if (e.key === '?') {
    e.preventDefault();
    showShortcuts.value = !showShortcuts.value;
    return;
  }
  if (e.key === 'Escape' && showShortcuts.value) {
    showShortcuts.value = false;
    return;
  }
  if (e.key === 'j' && adjacent.value.prev) {
    e.preventDefault();
    goAdjacent(adjacent.value.prev);
  } else if (e.key === 'k' && adjacent.value.next) {
    e.preventDefault();
    goAdjacent(adjacent.value.next);
  }
}

onMounted(() => window.addEventListener('keydown', onKeydown));
onUnmounted(() => window.removeEventListener('keydown', onKeydown));
</script>

<template>
  <div class="px-4 sm:px-6 lg:px-8 py-8">
    <div v-if="conceptLoading" class="max-w-5xl mx-auto py-8 space-y-5">
      <!-- Breadcrumb skeleton -->
      <div class="flex items-center gap-1.5">
        <div class="skeleton h-3 w-24"></div>
        <div class="skeleton h-3 w-4"></div>
        <div class="skeleton h-3 w-16"></div>
      </div>
      <!-- Title skeleton -->
      <div class="skeleton h-10 w-72"></div>
      <!-- Badge skeleton -->
      <div class="flex gap-2">
        <div class="skeleton h-5 w-20"></div>
        <div class="skeleton h-5 w-16"></div>
        <div class="skeleton h-5 w-28"></div>
      </div>
      <!-- Language section skeleton -->
      <div class="border border-ink-100/80 rounded-lg p-4 space-y-3">
        <div class="flex items-center gap-2">
          <div class="skeleton h-4 w-4"></div>
          <div class="skeleton h-5 w-40"></div>
          <div class="skeleton h-3 w-12"></div>
        </div>
        <div class="skeleton h-20 w-full"></div>
        <div class="skeleton h-4 w-3/4"></div>
      </div>
    </div>
    <div v-else-if="localError" class="max-w-xl mx-auto text-center py-20">
      <div class="card p-8 border-red-200 bg-red-50/50">
        <p class="text-red-700 font-medium mb-1">{{ t('concept.failedToLoad') }}</p>
        <p class="text-sm text-red-600/80 mb-4">{{ localError }}</p>
        <div class="flex gap-2 justify-center">
          <button @click="loadConcept(registerId, conceptId)" class="btn-primary">{{ t('dataset.retry') }}</button>
          <router-link :to="{ name: 'dataset', params: { registerId } }" class="btn-secondary">
            {{ t('concept.backToDataset') }}
          </router-link>
        </div>
      </div>
    </div>
    <div v-else-if="!concept" class="max-w-xl mx-auto text-center py-20">
      <div class="card p-8">
        <div class="text-ink-200 text-5xl mb-3 font-serif">?</div>
        <h3 class="text-lg font-medium text-ink-700 mb-2">{{ t('concept.notFound') }}</h3>
        <p class="text-sm text-ink-400 mb-4">{{ t('concept.notFoundMsg', { id: conceptId }) }}</p>
        <router-link :to="{ name: 'dataset', params: { registerId } }" class="btn-primary">
          {{ t('concept.backToDataset') }}
        </router-link>
      </div>
    </div>
    <ConceptDetail
      v-else-if="concept && manifest"
      :concept="concept"
      :manifest="manifest"
      :edges="edges"
      :adjacent="adjacent"
      :register-id="registerId"
    />

    <!-- Keyboard shortcuts modal -->
    <Teleport to="body">
      <div v-if="showShortcuts" class="fixed inset-0 z-50 flex items-center justify-center bg-black/30" @click.self="showShortcuts = false">
        <div class="bg-white rounded-xl shadow-2xl p-6 max-w-sm w-full mx-4 border border-ink-100">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-ink-800">Keyboard shortcuts</h3>
            <button @click="showShortcuts = false" class="p-1 rounded hover:bg-ink-50 text-ink-400 hover:text-ink-600">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="space-y-3 text-sm">
            <div class="flex items-center justify-between">
              <span class="text-ink-600">Previous concept</span>
              <kbd class="px-2 py-1 bg-ink-50 border border-ink-200 rounded text-xs font-mono">J</kbd>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-ink-600">Next concept</span>
              <kbd class="px-2 py-1 bg-ink-50 border border-ink-200 rounded text-xs font-mono">K</kbd>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-ink-600">Search</span>
              <kbd class="px-2 py-1 bg-ink-50 border border-ink-200 rounded text-xs font-mono">/</kbd>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-ink-600">Show shortcuts</span>
              <kbd class="px-2 py-1 bg-ink-50 border border-ink-200 rounded text-xs font-mono">?</kbd>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-ink-600">Close dialog</span>
              <kbd class="px-2 py-1 bg-ink-50 border border-ink-200 rounded text-xs font-mono">Esc</kbd>
            </div>
          </div>
          <div class="mt-4 pt-3 border-t border-ink-100 text-xs text-ink-300 text-center">
            Shortcuts only work when no input field is focused
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
