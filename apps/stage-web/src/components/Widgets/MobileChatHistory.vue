<script setup lang="ts">
import { useMarkdown } from '@proj-airi/stage-ui/composables'
import { useChatStore } from '@proj-airi/stage-ui/stores'
import { storeToRefs } from 'pinia'
import { nextTick, ref } from 'vue'
import { useI18n } from 'vue-i18n'

const chatHistoryRef = ref<HTMLDivElement>()

const { t } = useI18n()
const { messages } = storeToRefs(useChatStore())

const { process } = useMarkdown()
const { onBeforeMessageComposed, onTokenLiteral } = useChatStore()

onBeforeMessageComposed(async () => {
  // Scroll down to the new sent message
  nextTick().then(() => {
    if (!chatHistoryRef.value)
      return

    chatHistoryRef.value.scrollTop = chatHistoryRef.value.scrollHeight
  })
})

onTokenLiteral(async () => {
  // Scroll down to the new responding message
  nextTick().then(() => {
    if (!chatHistoryRef.value)
      return

    chatHistoryRef.value.scrollTop = chatHistoryRef.value.scrollHeight
  })
})
</script>

<template>
  <div flex="~ col" rounded="lg" overflow-hidden>
    <div ref="chatHistoryRef" v-auto-animate max-h="35dvh" z-5 flex="~ col" h-full w-full overflow-scroll class="chat-history">
      <div v-for="(message, index) in messages" :key="index" mb-2>
        <div v-if="message.role === 'error'" flex mr="12">
          <div
            flex="~ col"
            shadow="md violet-200/20 dark:none"
            min-w-20 rounded-lg px-3 py-2
            h="unset <sm:fit"
            bg="violet-100 dark:violet-800"
            backdrop-blur-sm
          >
            <div flex="~ row" items-center justify-between gap-2>
              <div>
                <span text-xs text="violet-400/90 dark:violet-600/90" font-normal>{{ t('stage.chat.message.character-name.core-system') }}</span>
              </div>
              <div i-solar:danger-triangle-bold-duotone text-violet-500 />
            </div>
            <div v-if="message.content" class="markdown-content break-words" text="base <sm:xs" v-html="process(message.content as string)" />
            <div v-else i-eos-icons:three-dots-loading />
          </div>
        </div>
        <div v-if="message.role === 'assistant'" flex mr="12">
          <div
            flex="~ col"
            shadow="md primary-200/20 dark:none"
            min-w-20 rounded-lg px-3 py-2
            h="unset <sm:fit"
            bg="primary-50 dark:primary-800"
            backdrop-blur-md
          >
            <div>
              <span text="primary-400/90 dark:primary-600/90" text-xs font-normal class="inline <sm:hidden">{{ t('stage.chat.message.character-name.airi') }}</span>
            </div>
            <div v-if="message.content" class="markdown-content break-words" text="base <sm:xs" v-html="process(message.content as string)" />
            <div v-else i-eos-icons:three-dots-loading />
          </div>
        </div>
        <div v-else-if="message.role === 'user'" flex="~">
          <div
            flex="~ col"
            shadow="md cyan-200/20 dark:none"
            px="2"
            h="unset <sm:fit" min-w-20 rounded-lg px-3 py-2
            bg="white dark:neutral-800"
            backdrop-blur-md
          >
            <div>
              <span text-xs text="cyan-400/90 dark:cyan-600/90" font-normal class="inline <sm:hidden">{{ t('stage.chat.message.character-name.you') }}</span>
            </div>
            <div v-if="message.content" class="markdown-content break-words" text="base <sm:xs" v-html="process(message.content as string)" />
            <div v-else />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/*
DO NOT ATTEMPT TO USE backdrop-filter TOGETHER WITH mask-image.

html - Why doesn't blur backdrop-filter work together with mask-image? - Stack Overflow
https://stackoverflow.com/questions/72780266/why-doesnt-blur-backdrop-filter-work-together-with-mask-image
*/
.chat-history {
  --gradient: linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,1) 20%);
  -webkit-mask-image: var(--gradient);
  mask-image: var(--gradient);
  -webkit-mask-size: 100% 100%;
  mask-size: 100% 100%;
  -webkit-mask-repeat: no-repeat;
  mask-repeat: no-repeat;
  -webkit-mask-position: bottom;
  mask-position: bottom;
}
</style>
