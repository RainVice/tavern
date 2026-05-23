import { appTasks } from '@ohos/hvigor-ohos-plugin';
// 1、导入
import { OptionalPluginConfig, routerRegisterPlugin } from 'router-register-plugin';

// 2、初始化配置
const config: OptionalPluginConfig = {
  logEnabled: true, // 查看日志
  viewNodeInfo: true, // 查看节点信息
  enableUiPreviewBuild: true, // 启用UI预览构建，不建议启动
  ignoredModules: ['router','openai_node','common']
}

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  // 3、添加插件
  plugins: [routerRegisterPlugin(config)]
}