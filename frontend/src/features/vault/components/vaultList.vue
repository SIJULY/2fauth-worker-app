<template>
  <div class="vault-list-wrapper" style="min-height: 400px;">
    <div class="vault-content">
      <el-affix :offset="layoutStore.isMobile ? 60 : 61" @change="(val) => isToolbarFixed = val">
        <div class="toolbar" :class="{ 'is-affixed': isToolbarFixed }" style="margin-bottom: 20px; display: flex; gap: 15px; align-items: center; justify-content: space-between; flex-wrap: wrap;">
        <div style="display: flex; align-items: center; gap: 10px; flex: 1;">
          <el-input 
            v-model="searchQuery" 
            :placeholder="$t('common.search_placeholder')" 
            clearable 
            style="max-width: 250px;"
            :disabled="isSortMode"
          >
            <template #prefix>
              <el-icon v-if="isFetching && searchQuery" class="is-loading"><Loading /></el-icon>
              <el-icon v-else><Search /></el-icon>
            </template>
          </el-input>

          <el-select v-model="category" :placeholder="$t('common.category_placeholder', '所有分类')" clearable style="width: 140px;" :disabled="isSortMode">
            <el-option :label="$t('common.all_categories', '所有分类')" value="" />
            <el-option v-for="cat in categories" :key="cat" :label="cat" :value="cat" />
          </el-select>

          <el-select v-model="sortBy" :placeholder="$t('common.sort_placeholder', '默认排序')" style="width: 140px;" :disabled="isSortMode">
            <el-option :label="$t('common.sort_default', '自定义排序')" value="" />
            <el-option :label="$t('common.sort_service_asc', '服务名称 (A-Z)')" value="service_asc" />
            <el-option :label="$t('common.sort_service_desc', '服务名称 (Z-A)')" value="service_desc" />
            <el-option :label="$t('common.sort_account_asc', '账号名称 (A-Z)')" value="account_asc" />
            <el-option :label="$t('common.sort_account_desc', '账号名称 (Z-A)')" value="account_desc" />
            <el-option :label="$t('common.sort_created_desc', '最新添加')" value="created_desc" />
            <el-option :label="$t('common.sort_created_asc', '最早添加')" value="created_asc" />
          </el-select>
        </div>
        
        <div class="batch-actions" style="display: flex; align-items: center; gap: 10px;">
          <el-button 
            v-if="vault.length > 0 && !searchQuery && !category && !sortBy && selectedIds.length === 0" 
            @click="toggleSortMode" 
            :type="isSortMode ? 'primary' : 'default'"
            plain
          >
            <el-icon><Sort /></el-icon> {{ isSortMode ? $t('common.finish_sorting', '完成排序') : $t('common.sort', '排序') }}
          </el-button>

          <template v-if="selectedIds.length > 0">
            <span class="batch-text">{{ $t('common.selected_items', { count: selectedIds.length }) }}</span>
            <el-button type="danger" plain @click="handleBulkDelete" :loading="isBulkDeleting">
              <el-icon><Delete /></el-icon> {{ $t('common.delete') }}
            </el-button>
            <el-button @click="selectedIds = []" plain>{{ $t('common.cancel') }}</el-button>
          </template>
          <el-button v-else @click="selectAllLoaded" plain>{{ $t('common.select_all_loaded') }}</el-button>
        </div>
      </div>
      </el-affix>

      <div v-if="(isInitializing || isLoading || isFetching) && vault.length === 0" class="loading-state" style="display: flex; flex-direction: column; justify-content: center; align-items: center; min-height: 400px; color: var(--el-text-color-secondary);">

        <el-icon class="is-loading" :size="48" style="margin-bottom: 20px; color: var(--el-color-primary);"><Loading /></el-icon>
        <p style="font-size: 16px; letter-spacing: 1px;">{{ $t('common.loading_data') }}</p>
      </div>

      <div v-else-if="!isLoading && !isFetching && vault.length === 0 && !searchQuery" class="empty-state">
        <el-empty :description="$t('common.empty_vault')">
          <el-button type="primary" @click="$emit('switch-tab', 'add-vault-scan')">{{ $t('common.go_add_vault') }}</el-button>
        </el-empty>
      </div>

      <div v-else
        class="list-container" 
        style="min-height: 200px;"
        v-infinite-scroll="handleLoadMore"
        :infinite-scroll-disabled="isLoadMoreDisabled"
        :infinite-scroll-distance="100"
      >
        <el-row :gutter="24" v-if="vault.length > 0" ref="sortableListRef">
          <el-col :xs="24" :sm="12" :md="12" :lg="8" :xl="6" v-for="vaultItem in vault" :key="vaultItem.id" style="margin-bottom: 24px;" class="sortable-col">
          
          <el-card class="vault-card custom-hover-card" :class="{ 'is-selected': selectedIds.includes(vaultItem.id), 'is-sort-mode': isSortMode }" shadow="never" :body-style="{ padding: '24px', display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }">
            <div class="card-header" style="margin-bottom: 20px; display: flex; align-items: flex-start; justify-content: space-between;">
              <div style="display: flex; align-items: center; gap: 16px; overflow: hidden; width: 100%;">
                
                <div v-if="isSortMode" class="drag-handle" style="cursor: grab; display: flex; align-items: center; color: var(--el-text-color-secondary); flex-shrink: 0;">
                  <svg viewBox="0 0 24 24" width="20" height="20" xmlns="http://www.w3.org/2000/svg">
                    <path fill="currentColor" d="M11 20.95c-.83 0-1.6-.33-2.18-.94l-4.57-4.75a1.27 1.27 0 0 1-.22-1.46c.21-.44.66-.7 1.15-.7c.36 0 .68.16.9.41l1.92 2.15v-9.16c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v4h.5v-7.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v7.5h.5v-6.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v6.5h.5V7c0-.83.67-1.5 1.5-1.5S19 6.17 19 7v8.86c0 2.81-2.24 5.09-5 5.09h-3z"/>
                  </svg>
                </div>
                <el-checkbox v-else :model-value="selectedIds.includes(vaultItem.id)" @change="toggleSelection(vaultItem.id)" @click.stop style="margin-right: 0;" />

                <div style="position: relative; width: 50px; height: 50px; border-radius: 14px; flex-shrink: 0; background-color: #ffffff; border: 1px solid var(--el-border-color-lighter); display: flex; align-items: center; justify-content: center; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06);">
                  <span style="color: var(--el-text-color-secondary); font-size: 22px; font-weight: bold; position: absolute; z-index: 1;">
                    {{ vaultItem.service ? vaultItem.service.charAt(0).toUpperCase() : '?' }}
                  </span>
                  <img 
                    v-if="getIconUrl(vaultItem)"
                    :src="getIconUrl(vaultItem)"
                    style="width: 100%; height: 100%; z-index: 2; object-fit: contain; position: relative; background-color: #ffffff; padding: 7px; box-sizing: border-box;"
                    @error="(e) => handleIconError(e, vaultItem)"
                  />
                </div>

                <div style="display: flex; flex-direction: column; overflow: hidden; flex: 1;">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <h3 style="margin: 0; font-size: 18px; color: var(--el-text-color-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 700;" :title="vaultItem.service">{{ vaultItem.service }}</h3>
                    <el-tag size="small" v-if="vaultItem.category" effect="light" style="border-radius: 10px; border: none; background-color: var(--el-color-primary-light-9);" round>{{ vaultItem.category }}</el-tag>
                  </div>
                  <p style="margin: 6px 0 0 0; font-size: 14px; color: #909399; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" :title="vaultItem.account">{{ vaultItem.account?.includes(':') ? vaultItem.account.split(':').pop() : vaultItem.account }}</p>
                </div>
              </div>

              <el-dropdown trigger="click" @command="(cmd) => handleCommand(cmd, vaultItem)" style="flex-shrink: 0; margin-left: 10px;">
                <el-icon class="more-icon" @click.stop style="font-size: 20px; cursor: pointer; color: var(--el-text-color-placeholder); transition: color 0.2s;"><MoreFilled /></el-icon>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item command="qr">
                      <el-icon><Picture /></el-icon> {{ $t('common.export_account') }}
                    </el-dropdown-item>
                    <el-dropdown-item command="edit">
                      <el-icon><Edit /></el-icon> {{ $t('common.edit') }}
                    </el-dropdown-item>
                    <el-dropdown-item command="delete" style="color: #F56C6C;">
                      <el-icon><Delete /></el-icon> {{ $t('common.delete') }}
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>

            <div class="code-display-area sleek-code-box" @click="copyCode(vaultItem)">
              <div style="display: flex; flex-direction: column;">
                <div style="font-size: 28px; font-weight: 800; letter-spacing: 4px; color: var(--el-text-color-primary); font-family: ui-monospace, SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace;" :data-digits="vaultItem.digits">
                  {{ vaultItem.currentCode ? vaultItem.currentCode.replace(/(.{3})/, '$1 ') : '--- ---' }}
                </div>
              </div>
              <div style="position: relative; display: flex; align-items: center; justify-content: center; width: 34px; height: 34px;">
                <el-progress
                  type="circle"
                  :percentage="vaultItem.percentage || 0"
                  :width="34"
                  :stroke-width="4"
                  :color="vaultItem.color || '#67C23A'"
                  :show-text="false"
                />
                <span style="position: absolute; font-size: 13px; font-weight: 700; font-family: monospace;" :style="{ color: vaultItem.color || '#67C23A' }">{{ vaultItem.remaining || 30 }}</span>
              </div>
            </div>
          </el-card>
          </el-col>
        </el-row>

        <div v-if="isFetchingNextPage" style="text-align: center; padding: 20px; color: var(--el-text-color-secondary);">
          <el-icon class="is-loading"><Loading /></el-icon> {{ $t('common.loading_more') }}
        </div>
        <div v-if="!hasNextPage && vault.length > 0" style="text-align: center; padding: 20px; color: var(--el-text-color-secondary); font-size: 12px;">
          {{ $t('common.no_more_accounts') }}
        </div>

        <el-empty v-if="!isLoading && vault.length === 0 && searchQuery" :description="$t('common.no_matching_accounts')" />
      </div>
    </div>

    <el-dialog v-model="showEditDialog" :title="$t('common.edit_account')" :width="layoutStore.isMobile ? '90%' : '400px'" destroy-on-close>
      <el-form :model="editVaultData" label-position="top">
        <el-form-item :label="$t('common.service_name')">
          <el-input v-model="editVaultData.service" />
        </el-form-item>
        <el-form-item :label="$t('common.account_identifier')">
          <el-input v-model="editVaultData.account" />
        </el-form-item>
        <el-form-item :label="$t('common.category_optional')">
          <el-select
            v-model="editVaultData.category"
            allow-create
            filterable
            default-first-option
            :placeholder="$t('common.category_placeholder', '所有分类')"
            style="width: 100%;"
          >
            <el-option v-for="cat in presetCategories" :key="cat.value" :label="cat.label" :value="cat.value">
              <div style="display: flex; align-items: center; gap: 8px;">
                <img v-if="cat.icon" :src="getIconUrl({ category: cat.value })" style="width: 16px; height: 16px; border-radius: 50%;" @error="(e) => e.target.style.display='none'" />
                <span>{{ cat.label }}</span>
              </div>
            </el-option>
            <el-option
              v-for="cat in categories.filter(c => !presetCategories.find(pc => pc.value === c))"
              :key="cat"
              :label="cat"
              :value="cat"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="showEditDialog = false">{{ $t('common.cancel') }}</el-button>
          <el-button type="primary" :loading="isEditing" @click="submitEditVault">{{ $t('common.save') }}</el-button>
        </span>
      </template>
    </el-dialog>

    <el-dialog v-model="showQrDialog" :title="$t('common.export_account')" :width="layoutStore.isMobile ? '90%' : '350px'" center align-center destroy-on-close @closed="showSecret = false">
      <div class="qr-container" v-if="currentQrItem">
        <div class="qr-info">
          <h3 class="qr-service">{{ currentQrItem.service }}</h3>
          <p class="qr-account">{{ currentQrItem.account }}</p>
        </div>
        
        <div class="qr-image-wrapper">
          <img :src="qrCodeUrl" class="qr-code-img" />
        </div>
        
        <p class="qr-tip">{{ $t('vault.export_qr_tip') }}</p>
        
        <div class="secret-section">
          <div class="secret-box">
            <div class="secret-text">{{ showSecret ? formatSecret(currentQrItem.secret) : '•••• •••• •••• ••••' }}</div>
            <div class="secret-actions">
              <el-icon class="action-icon" @click="showSecret = !showSecret" :title="showSecret ? $t('vault.hide_secret') : $t('vault.show_secret')"><View v-if="!showSecret" /><Hide v-else /></el-icon>
              <el-icon class="action-icon" @click="copySecret" :title="$t('vault.copy_secret')"><CopyDocument /></el-icon>
            </div>
          </div>
        </div>

        <div class="uri-link-wrapper">
          <el-button link type="info" size="small" @click="copyOtpUrl">{{ $t('vault.copy_otp_url') }}</el-button>
        </div>
      </div>
    </el-dialog>

  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { MoreFilled, Edit, Delete, Picture, View, Hide, CopyDocument, Loading, Search, Sort } from '@element-plus/icons-vue'
import { useLayoutStore } from '@/shared/stores/layoutStore'
import { useVaultStore } from '@/features/vault/store/vaultStore'
import { useVaultList } from '@/features/vault/composables/useVaultList'
import { useTotpTimer } from '@/features/vault/composables/useTotpTimer'
import { useVaultActions } from '@/features/vault/composables/useVaultActions'
import { vaultService } from '@/features/vault/service/vaultService'
import Sortable from 'sortablejs'
import { ElMessage } from 'element-plus'

const emit = defineEmits(['switch-tab'])
const layoutStore = useLayoutStore()
const vaultStore = useVaultStore()

const presetCategories = [
  { label: 'Google 谷歌', value: 'Google', icon: 'google' },
  { label: 'Microsoft 微软', value: 'Microsoft', icon: 'microsoft' },
  { label: 'Microsoft Azure 微软云', value: 'Microsoft Azure', icon: 'azure' },
  { label: 'Oracle 甲骨文云', value: 'Oracle Cloud', icon: 'oracle' },
  { label: 'GitHub', value: 'GitHub', icon: 'github' },
  { label: 'Cloudflare', value: 'Cloudflare', icon: 'cloudflare' },
  { label: 'Amazon 亚马逊云', value: 'Amazon AWS', icon: 'amazonaws' },
  { label: 'Apple', value: 'Apple', icon: 'apple' },
  { label: 'Facebook', value: 'Facebook', icon: 'facebook' },
  { label: 'X (Twitter)', value: 'X', icon: 'x' },
  { label: 'Discord', value: 'Discord', icon: 'discord' },
]

const localIcons = {
  'google': 'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2024%2024%22%3E%3Cpath%20fill%3D%22%234285F4%22%20d%3D%22M23.745%2012.27c0-.79-.07-1.54-.19-2.27h-11.3v4.51h6.47c-.29%201.48-1.14%202.73-2.4%203.58v3h3.86c2.26-2.09%203.56-5.17%203.56-8.82z%22%2F%3E%3Cpath%20fill%3D%22%2334A853%22%20d%3D%22M12.255%2024c3.24%200%205.95-1.08%207.93-2.91l-3.86-3c-1.08.72-2.45%201.16-4.07%201.16-3.13%200-5.78-2.11-6.73-4.96h-3.98v3.09C3.515%2021.3%207.565%2024%2012.255%2024z%22%2F%3E%3Cpath%20fill%3D%22%23FBBC05%22%20d%3D%22M5.525%2014.29c-.25-.72-.38-1.49-.38-2.29s.14-1.57.38-2.29V6.62h-3.98a11.86%2011.86%200%20000%2010.76l3.98-3.09z%22%2F%3E%3Cpath%20fill%3D%22%23EA4335%22%20d%3D%22M12.255%204.75c1.77%200%203.35.61%204.6%201.8l3.42-3.42C18.205%201.19%2015.495%200%2012.255%200%207.565%200%203.515%202.7%201.545%206.62l3.98%203.09c.95-2.85%203.6-4.96%206.73-4.96z%22%2F%3E%3C%2Fsvg%3E',
  'azure': 'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2024%2024%22%3E%3Cpath%20fill%3D%22%230089D6%22%20d%3D%22M5.483%2021.3H24L14.025%204.013l-3.3%205.418-2.616%204.316L5.483%2021.3z%22%2F%3E%3Cpath%20fill%3D%22%2300A2ED%22%20d%3D%22M13.25%202.7L.01%2021.3h7.973l2.842-4.662L13.25%202.7z%22%2F%3E%3C%2Fsvg%3E',
  'microsoft': 'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2024%2024%22%3E%3Cpath%20fill%3D%22%23f35325%22%20d%3D%22M1%201h10v10H1z%22%2F%3E%3Cpath%20fill%3D%22%2381bc06%22%20d%3D%22M13%201h10v10H13z%22%2F%3E%3Cpath%20fill%3D%22%2305a6f0%22%20d%3D%22M1%2013h10v10H1z%22%2F%3E%3Cpath%20fill%3D%22%23ffba08%22%20d%3D%22M13%2013h10v10H13z%22%2F%3E%3C%2Fsvg%3E',
  'oracle': 'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2024%2024%22%3E%3Cpath%20fill%3D%22%23F80000%22%20d%3D%22M17.433%203.492H6.567C2.946%203.492%200%206.438%200%2010.058v3.884c0%203.621%202.946%206.566%206.567%206.566h10.866c3.62%200%206.567-2.945%206.567-6.566v-3.884c0-3.62-2.946-6.566-6.567-6.566zm-10.866%2014.5c-2.22%200-4.02-1.8-4.02-4.02v-3.884c0-2.22%201.8-4.02%204.02-4.02h10.866c2.22%200%204.02%201.8%204.02%204.02v3.884c0%202.22-1.8%204.02-4.02%204.02H6.567z%22%2F%3E%3C%2Fsvg%3E',
}

const getIconUrl = (vaultItem) => {
  let targetName = ''

  if (vaultItem.category) {
    const preset = presetCategories.find(c => c.value === vaultItem.category)
    targetName = preset ? preset.icon : vaultItem.category
  } else if (vaultItem.service) {
    targetName = vaultItem.service
  }

  if (!targetName) return ''

  const cleanName = targetName.toLowerCase().replace(/[^a-z0-9]/g, '')

  for (const [key, codeString] of Object.entries(localIcons)) {
    if (cleanName.includes(key)) {
      return codeString
    }
  }

  const domainMap = {
    'amazon': 'aws.amazon.com',
    'aws': 'aws.amazon.com',
    'apple': 'apple.com',
    'github': 'github.com',
    'cloudflare': 'cloudflare.com',
    'binance': 'binance.com',
    'bybit': 'bybit.com',
    'discord': 'discord.com',
    'twitter': 'twitter.com',
    'facebook': 'facebook.com',
    'digitalocean': 'digitalocean.com',
    'hetzner': 'hetzner.com'
  }

  for (const [key, domain] of Object.entries(domainMap)) {
    if (cleanName.includes(key)) {
      return `https://api.iowen.cn/favicon/${domain}.png`
    }
  }

  return `https://cdn.simpleicons.org/${cleanName}`
}

const handleIconError = (e, vaultItem) => {
  if (e.target.dataset.fallback === 'true') {
    e.target.style.display = 'none'
    return
  }

  e.target.dataset.fallback = 'true'

  let targetName = vaultItem.category || vaultItem.service || ''
  const cleanName = targetName.toLowerCase().replace(/[^a-z0-9]/g, '')
  
  if (cleanName) {
    e.target.src = `https://cdn.simpleicons.org/${cleanName}`
  } else {
    e.target.style.display = 'none'
  }
}

const afterLoadRef = ref(null)

const {
    vault, categories, searchQuery, category, sortBy, isLoading, isFetching, isFetchingNextPage,
    hasNextPage, isLoadMoreDisabled, fetchVault, fetchCategories, handleLoadMore
} = useVaultList(afterLoadRef)

const { updateVaultStatus } = useTotpTimer(vault)

afterLoadRef.value = updateVaultStatus

const {
    selectedIds, isBulkDeleting,
    showEditDialog, isEditing, editVaultData,
    showQrDialog, currentQrItem, showSecret, qrCodeUrl,
    toggleSelection, selectAllLoaded, handleBulkDelete, copyCode,
    submitEditVault, openQrDialog, copySecret, copyOtpUrl,
    formatSecret, handleCommand,
} = useVaultActions(fetchVault, vault)

const isInitializing = ref(true)
const isToolbarFixed = ref(false)

const isSortMode = ref(false)
const sortableListRef = ref(null)
let sortableInstance = null

const toggleSortMode = () => {
    isSortMode.value = !isSortMode.value
    if (isSortMode.value) {
        nextTick(() => {
            initSortable()
        })
    } else {
        if (sortableInstance) {
            sortableInstance.destroy()
            sortableInstance = null
        }
    }
}

// 核心修复逻辑：在拖拽完毕并保存服务器后，强制拉取底层数据覆盖旧缓存
const initSortable = () => {
    if (sortableListRef.value && sortableListRef.value.$el) {
        sortableInstance = new Sortable(sortableListRef.value.$el, {
            animation: 150,
            handle: '.drag-handle',
            draggable: '.sortable-col',
            onEnd: async (evt) => {
                const { oldIndex, newIndex } = evt
                if (oldIndex === newIndex) return

                const newVault = [...vault.value]
                const movedItem = newVault.splice(oldIndex, 1)[0]
                newVault.splice(newIndex, 0, movedItem)

                const updates = newVault.map((item, index) => ({
                    id: item.id,
                    sortOrder: index
                }))

                try {
                    // 1. 乐观更新，让UI立即改变
                    vault.value = newVault
                    
                    // 2. 将最新的排序上报给服务器 (CF D1 数据库)
                    await vaultService.updateSortOrder(updates)
                    
                    // 3. ✨强一致性修复：通过主动调用 fetchVault 触发底层 Vue Query 的缓存刷新
                    if (typeof fetchVault === 'function') {
                        await fetchVault()
                    }
                    
                    ElMessage.success('排序已保存')
                } catch (e) {
                    ElMessage.error('排序保存失败')
                    // 发生错误时如果能拉取数据就拉取，否则回退前端的UI状态
                    if (typeof fetchVault === 'function') {
                        fetchVault()
                    } else {
                        vault.value = [...vault.value]
                    }
                }
            }
        })
    }
}

const handleUnlocked = async () => {
    try {
        if (vaultStore.isDirty) return
        const vaultData = await vaultStore.getData()
        if (vaultData && vaultData.vault) {
            vault.value = vaultData.vault
            setTimeout(() => updateVaultStatus(), 0)
        }
    } finally {
        isInitializing.value = false
    }
}

defineExpose({ fetchVault })

onMounted(() => {
    handleUnlocked()
    fetchCategories()
})
</script>

<style scoped>
.toolbar {
  transition: padding 0.3s ease, background-color 0.3s ease;
  box-sizing: border-box;
}

.toolbar.is-affixed {
  z-index: 2000;
  margin-bottom: 0 !important;
  background-color: var(--el-bg-color-page);
}

@media (max-width: 767px) {
  .toolbar.is-affixed {
    width: 100vw !important;
    margin-left: -20px !important;
    padding: 14px 20px !important;
    border-radius: 0 !important;
  }
}

@media (min-width: 768px) {
  .toolbar.is-affixed {
    border-bottom: none !important;
    padding: 20px 0px !important;
  }
}

/* UI 升级：卡片基础样式增强（大圆角、细腻边框过渡） */
:deep(.custom-hover-card) {
  border-radius: 16px;
  border: 1px solid var(--el-border-color-lighter);
  background-color: var(--el-bg-color);
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

/* UI 升级：悬浮动态效果 */
:deep(.custom-hover-card:hover) {
  transform: translateY(-4px);
  box-shadow: 0 16px 32px rgba(0, 0, 0, 0.06) !important;
  border-color: var(--el-color-primary-light-7);
}

/* UI 升级：验证码框的拟物通透设计 */
.sleek-code-box {
  display: flex;
  align-items: center;
  justify-content: space-between;
  /* 微渐变底色 */
  background: linear-gradient(145deg, var(--el-fill-color-light) 0%, var(--el-bg-color) 100%);
  border: 1px solid var(--el-border-color-lighter);
  padding: 16px 20px;
  border-radius: 14px;
  margin-top: auto;
  cursor: pointer;
  transition: all 0.2s ease;
}

.sleek-code-box:hover {
  background: var(--el-fill-color);
  border-color: var(--el-color-primary-light-5);
}

.more-icon:hover {
  color: var(--el-color-primary) !important;
}

.vault-card.is-sort-mode {
  border: 1px dashed var(--el-color-primary-light-5);
  transition: all 0.3s ease;
}
.drag-handle {
  font-size: 18px;
}
</style>
