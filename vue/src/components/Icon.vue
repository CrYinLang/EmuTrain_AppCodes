<template>
  <span
    class="material-symbols-rounded"
    :style="{ fontSize: size + 'px', color: color, fontVariationSettings: fill ? `'FILL' 1` : '' }"
  >{{ name }}</span>
</template>

<script setup>
defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: 24 },
  color: { type: String, default: 'inherit' },
  fill: { type: Boolean, default: false },
})
</script>

<style scoped>
.material-symbols-rounded {
  font-variation-settings:
    'FILL' 0,
    'wght' 400,
    'GRAD' 0,
    'opsz' 24;
  user-select: none;
  vertical-align: middle;
  line-height: 1;
}
</style>
