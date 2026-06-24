<template>
  <el-container class="home-container">
    <el-container class="main-body">

      <AppSidebar :active-tab="activeTab" @select="activeTab = $event" />

      <el-main class="main-content">
        <div v-if="activeTab === 'vault'" class="view-container">
          <VaultList ref="vaultListRef" @switch-tab="activeTab = $event" />
        </div>

        <div v-if="activeTab === 'add-vault-scan'" class="view-container">
          <AddVaultScan @success="handleSuccess" />
        </div>
        <div v-if="activeTab === 'add-vault-manual'" class="view-container">
          <AddVaultManual @success="handleSuccess" />
        </div>

        <div v-if="activeTab === 'migration-export'" class="view-container">
          <DataExport />
        </div>

        <div v-if="activeTab === 'migration-import'" class="view-container">
          <DataImport @success="handleSuccess" />
        </div>

        <div v-if="activeTab === 'backups'" class="view-container">
          <DataBackup @success="handleSuccess" />
        </div>

        <div v-if="activeTab === 'tool-totp'" class="view-container">
          <ToolTotp />
        </div>
        <div v-if="activeTab === 'tool-password'" class="view-container">
          <ToolPassword />
        </div>
        <div v-if="activeTab === 'tool-time'" class="view-container">
          <ToolTime />
        </div>
        <div v-if="activeTab === 'tool-qr'" class="view-container">
          <ToolQr />
        </div>

      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { ref, nextTick, watch, onMounted } from 'vue'
import AppSidebar from '@/features/vault/components/appSidebar.vue'
import { useLayoutStore } from '@/shared/stores/layoutStore'
import { createAsyncComponent } from '@/shared/utils/asyncHelper'

const layoutStore = useLayoutStore()

const VaultList      = createAsyncComponent(() => import('@/features/vault/components/vaultList.vue'))
const AddVaultScan   = createAsyncComponent(() => import('@/features/vault/components/addVaultScan.vue'))
const AddVaultManual = createAsyncComponent(() => import('@/features/vault/components/addVaultManual.vue'))
const DataExport     = createAsyncComponent(() => import('@/features/migration/views/dataExport.vue'))
const DataImport     = createAsyncComponent(() => import('@/features/migration/views/dataImport.vue'))
const DataBackup     = createAsyncComponent(() => import('@/features/backup/views/dataBackup.vue'))

// 导入拆分后的 4 个独立工具组件
const ToolTotp       = createAsyncComponent(() => import('@/features/tools/components/totpSecret.vue'))
const ToolPassword   = createAsyncComponent(() => import('@/features/tools/components/passwordGenerator.vue'))
const ToolTime       = createAsyncComponent(() => import('@/features/tools/components/timeSync.vue'))
const ToolQr         = createAsyncComponent(() => import('@/features/tools/components/qrParser.vue'))

const sessionKey = 'activeTab'
const activeTab    = ref(sessionStorage.getItem(sessionKey) || 'vault')

onMounted(() => {
  // 强制校准：加入了新的工具 tab 验证白名单
  const validTabs = [
    'vault', 'add-vault-scan', 'add-vault-manual', 
    'migration-export', 'migration-import', 'backups', 
    'tool-totp', 'tool-password', 'tool-time', 'tool-qr'
  ]
  if (!validTabs.includes(activeTab.value)) {
    activeTab.value = 'vault'
  }
})

watch(activeTab, (newVal) => {
  sessionStorage.setItem(sessionKey, newVal)
})

const vaultListRef = ref(null)

// 操作成功后：跳回账户列表并刷新数据
let pendingRefetch = false

const handleSuccess = () => {
  activeTab.value = 'vault'
  if (vaultListRef.value) {
    nextTick(() => vaultListRef.value?.fetchVault())
  } else {
    // VaultList 是懒加载组件，标记待刷新，等 ref 绑定后执行
    pendingRefetch = true
  }
}

watch(vaultListRef, (ref) => {
  if (ref && pendingRefetch) {
    pendingRefetch = false
    nextTick(() => ref.fetchVault())
  }
})

// 监听头部 Logo 点击事件，无刷新跳回主列表
watch(() => layoutStore.homeTabReset, () => {
  if (activeTab.value !== 'vault') {
    activeTab.value = 'vault'
  }
  // 强制刷新一下列表数据
  if (vaultListRef.value) {
    nextTick(() => vaultListRef.value?.fetchVault())
  } else {
    pendingRefetch = true
  }
})
</script>
