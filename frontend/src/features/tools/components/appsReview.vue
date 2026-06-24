<template>
  <div class="apps-review-container">
    <div class="review-header">
      <el-alert
        :title="$t('tools.apps_review_tool_desc')"
        type="info"
        show-icon
        :closable="false"
        class="mb-4"
      />
    </div>

    <el-row :gutter="20" class="cards-grid">
      <el-col
        v-for="app in appList"
        :key="app.id"
        :xs="24"
        :sm="24"
        :md="12"
        :lg="12"
        :xl="8"
        class="card-col"
      >
        <el-card shadow="hover" class="app-card" :class="{'security-alert': app.securityIssue}">
          <div class="app-header">
            <h3 class="app-name">
              <el-icon :size="28" class="app-logo">
                <component :is="app.icon" />
              </el-icon>
              {{ app.name }}
              <el-tag v-if="app.recommended" type="success" effect="dark" size="small" class="ml-2">🏅 Recommended</el-tag>
              <el-tag v-if="app.securityIssue" type="danger" effect="dark" size="small" class="ml-2">⚠️ Warning</el-tag>
            </h3>
            <div class="rating-box">
              <el-rate v-model="app.rating" disabled allow-half show-score text-color="#ff9900" score-template="{value}" />
            </div>
          </div>
          
          <div class="app-meta">
            <!-- 官网链接带有类图标表现 -->
            <el-link v-if="app.link" :href="app.link" target="_blank" type="primary" :underline="false" class="website-link">
                {{ $t('tools.apps_review_table.website') }}
            </el-link>

            <span class="downloads-label" v-if="app.downloads">{{ $t('tools.apps_review_table.platforms') }}:</span>
            
            <div class="platform-buttons" v-if="app.downloads">
              <el-tooltip v-if="app.downloads.ios" content="App Store" placement="top">
                <el-link :href="app.downloads.ios" target="_blank" :underline="false" class="platform-btn">
                  <el-icon><Apple /></el-icon>
                </el-link>
              </el-tooltip>
              <el-tooltip v-if="app.downloads.android" content="Google Play" placement="top">
                <el-link :href="app.downloads.android" target="_blank" :underline="false" class="platform-btn">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="1em" height="1em" fill="currentColor">
					          <path d="M 5.4160156 2.328125 L 13.296875 10.535156 L 15.626953 8.109375 C 11.611953 5.838375 6.3020156 2.834125 5.4160156 2.328125 z M 3.140625 2.8476562 C 3.055625 3.0456562 3 3.2629063 3 3.5039062 L 3 20.591797 C 3 20.788797 3.044375 20.970625 3.109375 21.140625 L 11.910156 11.978516 L 3.140625 2.8476562 z M 17.423828 9.1269531 L 14.683594 11.978516 L 17.402344 14.810547 C 19.071344 13.865547 20.226562 13.210937 20.226562 13.210938 C 20.725562 12.907937 21.005047 12.441594 20.998047 11.933594 C 20.991047 11.438594 20.702609 10.981938 20.224609 10.710938 C 20.159609 10.673937 19.031828 10.035953 17.423828 9.1269531 z M 13.296875 13.423828 L 5.4746094 21.566406 C 6.8216094 20.800406 11.797469 17.982172 15.605469 15.826172 L 13.296875 13.423828 z"/>
                  </svg>
                </el-link>
              </el-tooltip>
              <el-tooltip v-if="app.downloads.github" content="GitHub Releases" placement="top">
                <el-link :href="app.downloads.github" target="_blank" :underline="false" class="platform-btn">
                  <svg viewBox="0 0 24 24" width="1em" height="1em" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
                    <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.45-1.15-1.11-1.46-1.11-1.46-.9-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0012 2z"/>
                  </svg>
                </el-link>
              </el-tooltip>
              <el-tooltip v-if="app.downloads.fdroid" content="F-Droid" placement="top">
                <el-link :href="app.downloads.fdroid" target="_blank" :underline="false" class="platform-btn">
                  <span style="font-weight: bold; font-family: monospace;">FD</span>
                </el-link>
              </el-tooltip>
              <el-tooltip v-if="app.downloads.extension || app.downloads.desktop" content="Extension / Desktop" placement="top">
                <el-link :href="app.downloads.extension || app.downloads.desktop" target="_blank" :underline="false" class="platform-btn">
                  <el-icon><Monitor /></el-icon>
                </el-link>
              </el-tooltip>
            </div>
          </div>

          <el-divider border-style="dashed" class="meta-divider" />

          <div class="app-details">
            <div class="detail-item pros">
              <span class="label"><el-icon color="#67C23A"><Select /></el-icon> {{ $t('tools.apps_review_table.pros') }}:</span>
              <span class="value">{{ $t(`tools.apps.${app.id}.pros`) }}</span>
            </div>
            <div class="detail-item cons">
              <span class="label"><el-icon color="#909399"><CloseBold /></el-icon> {{ $t('tools.apps_review_table.cons') }}:</span>
              <span class="value">{{ $t(`tools.apps.${app.id}.cons`) }}</span>
            </div>
            <div class="detail-item security" v-if="app.securityIssue || $t(`tools.apps.${app.id}.security`) !== '无安全事故记录'">
              <span class="label" :class="{'text-danger': app.securityIssue}"><el-icon><Warning /></el-icon> {{ $t('tools.apps_review_table.security') }}:</span>
              <span class="value" :class="{'text-danger': app.securityIssue}">{{ $t(`tools.apps.${app.id}.security`) }}</span>
            </div>
            
            <div class="summary-box" :class="{'summary-danger': app.rating <= 2}">
              <strong>{{ $t('tools.apps_review_table.summary') }}: </strong>
              {{ $t(`tools.apps.${app.id}.summary`) }}
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { Monitor, Link, House, Warning, Select, CloseBold, Apple } from '@element-plus/icons-vue'

import Icon2FAS from '@/shared/components/icons/icon2FAS.vue'
import IconAegis from '@/shared/components/icons/iconAegis.vue'
import IconEnte from '@/shared/components/icons/iconEnte.vue'
import IconProtonAuth from '@/shared/components/icons/iconProtonAuth.vue'
import IconBitwarden from '@/shared/components/icons/iconBitwarden.vue'
import IconMicrosoftAuth from '@/shared/components/icons/iconMicrosoftAuth.vue'
import IconGoogleAuth from '@/shared/components/icons/iconGoogleAuth.vue'
import IconFreeOTP from '@/shared/components/icons/iconFreeOTP.vue'
import IconAuthy from '@/shared/components/icons/iconAuthy.vue'
import IconLastPass from '@/shared/components/icons/iconLastPass.vue'
import IconRaivo from '@/shared/components/icons/iconRaivo.vue'

const appList = [
  { id: '2fas', name: '2FAS Auth', rating: 5, icon: Icon2FAS, link: 'https://2fas.com/', recommended: true, securityIssue: false, downloads: { ios: 'https://apps.apple.com/us/app/2fas-authenticator/id1217793794', android: 'https://play.google.com/store/apps/details?id=com.twofasapp', github: 'https://github.com/twofas/2fas-android', extension: 'https://chrome.google.com/webstore/detail/2fas-authenticator/jnlkjeecnpjoeoojhkehdjhhnhbepfki' } },
  { id: 'ente', name: 'Ente Auth', rating: 4.8, icon: IconEnte, link: 'https://ente.io/auth/', recommended: true, securityIssue: false, downloads: { ios: 'https://apps.apple.com/app/ente-authenticator/id6444101188', android: 'https://play.google.com/store/apps/details?id=io.ente.auth', fdroid: 'https://f-droid.org/packages/io.ente.auth', github: 'https://github.com/ente-io/ente/releases', desktop: 'https://ente.io/download/auth/desktop' } },
  { id: 'aegis', name: 'Aegis Authenticator', rating: 4.8, icon: IconAegis, link: 'https://getaegis.app/', recommended: true, securityIssue: false, downloads: { android: 'https://play.google.com/store/apps/details?id=com.beemdevelopment.aegis', fdroid: 'https://f-droid.org/packages/com.beemdevelopment.aegis/', github: 'https://github.com/beemdevelopment/Aegis/releases' } },
  { id: 'proton', name: 'Proton Authenticator', rating: 4.5, icon: IconProtonAuth, link: 'https://proton.me/pass', recommended: false, securityIssue: false, downloads: { ios: 'https://apps.apple.com/us/app/proton-pass-password-manager/id6443490729', android: 'https://play.google.com/store/apps/details?id=me.proton.android.pass', extension: 'https://chrome.google.com/webstore/detail/proton-pass-free-password/ghmbeldphafepmbegfdlkmapnddhbheg' } },
  { id: 'bitwarden', name: 'Bitwarden Authenticator', rating: 4.2, icon: IconBitwarden, link: 'https://bitwarden.com/products/authenticator/', recommended: false, securityIssue: false, downloads: { ios: 'https://apps.apple.com/us/app/bitwarden-authenticator/id6475654992', android: 'https://play.google.com/store/apps/details?id=com.bitwarden.authenticator', github: 'https://github.com/bitwarden/authenticator/releases' } },
  { id: 'google', name: 'Google Authenticator', rating: 4.0, icon: IconGoogleAuth, link: 'https://safety.google/authentication/', recommended: false, securityIssue: false, downloads: { ios: 'https://apps.apple.com/us/app/google-authenticator/id388497605', android: 'https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2' } },
  { id: 'freeotp', name: 'FreeOTP', rating: 3.0, icon: IconFreeOTP, link: 'https://freeotp.github.io/', recommended: false, securityIssue: false, downloads: { ios: 'https://apps.apple.com/us/app/freeotp-authenticator/id872559395', android: 'https://play.google.com/store/apps/details?id=org.fedorahosted.freeotp', fdroid: 'https://f-droid.org/en/packages/org.fedorahosted.freeotp/' } },
  { id: 'microsoft', name: 'Microsoft Authenticator', rating: 2.0, icon: IconMicrosoftAuth, link: 'https://www.microsoft.com/en-us/security/mobile-authenticator-app', recommended: false, securityIssue: true, downloads: { ios: 'https://apps.apple.com/us/app/microsoft-authenticator/id983156458', android: 'https://play.google.com/store/apps/details?id=com.azure.authenticator' } },
  { id: 'authy', name: 'Authy', rating: 1.5, icon: IconAuthy, link: 'https://authy.com/', recommended: false, securityIssue: true, downloads: { ios: 'https://apps.apple.com/us/app/twilio-authy/id494168017', android: 'https://play.google.com/store/apps/details?id=com.authy.authy' } },
  { id: 'lastpass', name: 'LastPass Auth', rating: 1.5, icon: IconLastPass, link: 'https://www.lastpass.com/auth', recommended: false, securityIssue: true, downloads: { ios: 'https://apps.apple.com/us/app/lastpass-authenticator/id1079110004', android: 'https://play.google.com/store/apps/details?id=com.lastpass.authenticator' } },
  { id: 'raivo', name: 'Raivo OTP', rating: 1.0, icon: IconRaivo, link: 'https://raivo-otp.com/', recommended: false, securityIssue: true, downloads: { ios: 'https://apps.apple.com/us/app/raivo-otp/id1459042137' } }
]
</script>

<style scoped>
.apps-review-container {
  padding: 10px 0;
}

.mb-4 {
  margin-bottom: 20px;
}

.cards-grid {
  display: flex;
  flex-wrap: wrap;
}

.card-col {
  margin-bottom: 20px;
}

.app-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, box-shadow 0.2s;
  border-radius: 10px;
}

.app-card:hover {
  transform: translateY(-2px);
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.app-name {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.app-logo {
  background-color: transparent;
  flex-shrink: 0;
}

.rating-box {
  flex-shrink: 0;
}

.app-meta {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.download-link {
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.app-meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap; /* 空间不够时允许换行 */
  gap: 8px;
  margin-bottom: 12px;
}

.website-tag {
  display: flex;
  align-items: center;
  gap: 4px;
}

.website-link {
  text-decoration: none !important;
}

.downloads-label {
  font-size: 13px;
  color: var(--el-text-color-regular);
  margin-left: 4px;
}

.platform-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}

.platform-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 4px;
  background-color: transparent;
  color: var(--el-text-color-regular);
  border: none;
  font-size: 16px;
  text-decoration: none !important;
}

:global(html.dark) .platform-btn {
  color: var(--el-text-color-regular);
}

.meta-divider {
  margin: 12px 0;
}

.app-details {
  display: flex;
  flex-direction: column;
  gap: 10px;
  font-size: 14px;
  color: var(--el-text-color-regular);
}

.detail-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  line-height: 1.5;
}

.detail-item .label {
  font-weight: 500;
  min-width: 85px;
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}

.detail-item .value {
  flex-grow: 1;
}

.text-danger {
  color: var(--el-color-danger);
  font-weight: 500;
}

.summary-box {
  margin-top: 8px;
  padding: 12px;
  background-color: var(--el-fill-color-light);
  border-radius: 6px;
  font-size: 13px;
  line-height: 1.5;
  border-left: 3px solid var(--el-color-primary);
}

.summary-danger {
  background-color: var(--el-color-danger-light-9);
  border-left: 3px solid var(--el-color-danger);
}

:global(html.dark) .summary-danger {
  background-color: rgba(245, 108, 108, 0.1);
}

@media (max-width: 768px) {
  .app-header {
    flex-direction: column;
    gap: 8px;
  }
  
  .detail-item {
    flex-direction: column;
    align-items: flex-start;
  }

  .detail-item .label {
    margin-bottom: 2px;
  }
}
</style>
