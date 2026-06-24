<template>
  <div class="add-vault-wrapper">
    <div class="tab-card-wrapper">
      <h2 style="text-align: center; margin-bottom: 20px;">{{ $t('vault.manual_title') }}</h2>
      <div style="max-width: 100%; margin: 0 auto;">
        <el-form :model="newVault" label-position="top" :rules="rules" ref="addFormRef" style="padding: 10px 0;">
          <el-form-item :label="$t('common.service_name')" prop="service">
            <el-input v-model="newVault.service" :placeholder="$t('vault.input_service_placeholder')" />
          </el-form-item>
          <el-form-item :label="$t('common.account_identifier')" prop="account">
            <el-input v-model="newVault.account" :placeholder="$t('vault.input_account_placeholder')" />
          </el-form-item>
          <el-form-item :label="$t('vault.input_secret_label')" prop="secret">
            <el-input v-model="newVault.secret" :placeholder="$t('vault.input_secret_placeholder')" clearable>
              <template #append>
                <el-button @click="generateRandomSecret" :title="$t('vault.generate_random_secret')"><el-icon><Refresh /></el-icon></el-button>
              </template>
            </el-input>
          </el-form-item>
          <el-row :gutter="20">
            <el-col :span="8">
              <el-form-item :label="$t('vault.digits_label')" prop="digits">
                <el-select v-model="newVault.digits" style="width: 100%">
                  <el-option :label="$t('vault.digits_6')" :value="6" />
                  <el-option :label="$t('vault.digits_8')" :value="8" />
                </el-select>
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item :label="$t('vault.period_label')" prop="period">
                <el-select v-model="newVault.period" style="width: 100%">
                  <el-option :label="$t('vault.period_30s')" :value="30" />
                  <el-option :label="$t('vault.period_60s')" :value="60" />
                </el-select>
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item :label="$t('vault.algorithm_label')" prop="algorithm">
                <el-select v-model="newVault.algorithm" style="width: 100%">
                  <el-option :label="$t('vault.algo_sha1')" value="SHA1" />
                  <el-option label="SHA256" value="SHA256" />
                  <el-option label="SHA512" value="SHA512" />
                </el-select>
              </el-form-item>
            </el-col>
          </el-row>
          <el-form-item :label="$t('common.category_optional')" prop="category">
            <el-select
              v-model="newVault.category"
              allow-create
              filterable
              default-first-option
              :placeholder="$t('vault.input_category_placeholder')"
              style="width: 100%;"
            >
              <!-- 预设的带官方图标的分类 -->
              <el-option v-for="cat in presetCategories" :key="cat.value" :label="cat.label" :value="cat.value">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <img v-if="cat.icon" :src="cat.icon === 'oracle' ? 'https://logo.clearbit.com/oracle.com' : cat.icon === 'amazonaws' ? 'https://logo.clearbit.com/aws.amazon.com' : `https://cdn.simpleicons.org/${cat.icon}`" style="width: 16px; height: 16px; border-radius: 50%;" @error="(e) => e.target.style.display='none'" />
                  <span>{{ cat.label }}</span>
                </div>
              </el-option>
              <!-- 用户已有的其他分类 -->
              <el-option
                v-for="cat in categories.filter(c => !presetCategories.find(pc => pc.value === c))"
                :key="cat"
                :label="cat"
                :value="cat"
              />
            </el-select>
          </el-form-item>
          <el-form-item style="margin-top: 30px;">
            <el-button type="primary" :loading="submitting" @click="submitAddVault" style="width: 100%;" size="large">{{ $t('vault.confirm_add_btn') }}</el-button>
          </el-form-item>
        </el-form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import { bytesToBase32 } from '@/shared/utils/totp'
import { useVaultStore } from '@/features/vault/store/vaultStore'
import { vaultService } from '@/features/vault/service/vaultService'
import { onMounted } from 'vue'

const emit = defineEmits(['success'])

const { t } = useI18n()

// 预设分类列表
const presetCategories = [
  { label: 'Google 谷歌', value: 'Google', icon: 'google' },
  { label: 'Microsoft 微软云', value: 'Microsoft', icon: 'microsoft' },
  { label: 'Oracle 甲骨文云', value: 'Oracle Cloud', icon: 'oracle' },
  { label: 'GitHub', value: 'GitHub', icon: 'github' },
  { label: 'Cloudflare', value: 'Cloudflare', icon: 'cloudflare' },
  { label: 'Amazon 亚马逊云', value: 'Amazon AWS', icon: 'amazonaws' },
  { label: 'Apple', value: 'Apple', icon: 'apple' },
  { label: 'Facebook', value: 'Facebook', icon: 'facebook' },
  { label: 'X (Twitter)', value: 'X', icon: 'x' },
  { label: 'Discord', value: 'Discord', icon: 'discord' },
]

const categories = ref([])

onMounted(async () => {
  try {
    const response = await vaultService.getCategories()
    if (response.success && Array.isArray(response.data)) {
      categories.value = response.data
    }
  } catch (error) {
    console.error('Failed to load categories', error)
  }
})

const vaultStore = useVaultStore()
const submitting = ref(false)
const addFormRef = ref(null)
const newVault = ref({
  service: '', account: '', secret: '', category: '', digits: 6, period: 30, algorithm: 'SHA1'
})

const validateSecret = (rule, value, callback) => {
  if (!value) {
    return callback(new Error(t('vault.require_secret')))
  }
  // 移除空格后检查
  const clean = value.replace(/\s/g, '')
  if (clean.length < 16) {
    return callback(new Error(t('vault.secret_min_length')))
  }
  if (!/^[A-Z2-7]+$/i.test(clean)) {
    return callback(new Error(t('vault.secret_invalid_char')))
  }
  callback()
}

const rules = {
  service: [{ required: true, message: t('vault.require_service'), trigger: 'blur' }],
  account: [{ required: true, message: t('vault.require_account'), trigger: 'blur' }],
  secret: [{ required: true, validator: validateSecret, trigger: 'blur' }]
}

const generateRandomSecret = () => {
  const array = new Uint8Array(20)
  window.crypto.getRandomValues(array)
  newVault.value.secret = bytesToBase32(array)
}

const submitAddVault = async () => {
  if (!addFormRef.value) return
  await addFormRef.value.validate(async (valid) => {
    if (valid) {
      submitting.value = true
      try {
        const data = await vaultService.createAccount(newVault.value)
        if (data.success) {
          ElMessage.success(t('vault.add_success'))
          newVault.value = { service: '', account: '', secret: '', category: '', digits: 6, period: 30, algorithm: 'SHA1' }
          vaultStore.markDirty() // 实际写入数据，标记缓存过期
          emit('success')
        }
      } catch (error) {
      } finally {
        submitting.value = false
      }
    }
  })
}
</script>