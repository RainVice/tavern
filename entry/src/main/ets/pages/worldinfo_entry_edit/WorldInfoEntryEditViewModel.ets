import { ZRouter } from '@hzw/zrouter'
import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import { RVRouter } from 'router'
import type { WorldInfoEntry, WorldInfoEntryCreateParams, WorldInfoEntryUpdateParams } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import type { WorldInfoEntryEditPageParam } from './WorldInfoEntryEditPage'
import { WorldInfoEntryEditState } from './WorldInfoEntryEditState'

export class WorldInfoEntryEditViewModel {
  private state: WorldInfoEntryEditState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: WorldInfoEntryEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as WorldInfoEntryEditPageParam | undefined
    if (param !== undefined) {
      this.state.worldBookId = param.worldBookId
      if (param.entry !== undefined) {
        this.initFromEntry(param.entry)
      }
    }
  }

  onSave(): boolean {
    if (this.state.worldBookId.length === 0) {
      ToastUtil.showToast($r("app.string.world_book_not_found"))
      return false
    }
    if (this.state.content.trim().length === 0) {
      ToastUtil.showToast($r("app.string.world_info_entry_content_empty"))
      return false
    }
    this.saveEntry().then(() => {
      RVRouter.pop(true)
    }).catch((error: Error) => {
      LogUtil.setDomain()
      LogUtil.debug('WorldInfoEntryEditViewModel', 'onSave', '保存世界书条目失败', error.message)
      ToastUtil.showToast($r("app.string.world_info_entry_save_failed"))
    })
    return true
  }

  private initFromEntry(entry: WorldInfoEntry): void {
    this.state.entryId = entry.id
    this.state.comment = entry.comment
    this.state.keysText = entry.keys.join(', ')
    this.state.secondaryKeysText = entry.secondaryKeys.join(', ')
    this.state.content = entry.content
    this.state.constant = entry.constant
    this.state.selective = entry.selective
    this.state.enabled = entry.enabled
    this.state.insertionOrderText = entry.insertionOrder.toString()
    this.state.position = entry.position
    this.state.caseSensitive = entry.caseSensitive
    this.state.matchWholeWords = entry.matchWholeWords ?? false
    this.state.probabilityText = (entry.probability ?? 100).toString()
    this.state.excludeRecursion = entry.excludeRecursion ?? false
    this.state.depthText = (entry.depth ?? 0).toString()
    this.state.scanDepthText = (entry.scanDepth ?? 0).toString()
    this.state.role = entry.role ?? 'all'
    this.state.group = entry.group ?? ''
    this.state.groupOverride = entry.groupOverride ?? false
    this.state.groupWeightText = (entry.groupWeight ?? 100).toString()
    this.state.automationId = entry.automationId ?? ''
  }

  private async saveEntry(): Promise<void> {
    if (this.state.entryId.length > 0) {
      const params: WorldInfoEntryUpdateParams = this.buildUpdateParams()
      await this.runtime.worldInfo.updateEntry(this.state.worldBookId, this.state.entryId, params)
    } else {
      const params: WorldInfoEntryCreateParams = this.buildCreateParams()
      await this.runtime.worldInfo.createEntry(this.state.worldBookId, params)
    }
  }

  private buildCreateParams(): WorldInfoEntryCreateParams {
    return {
      comment: this.state.comment.trim(),
      keys: this.splitKeywords(this.state.keysText),
      secondaryKeys: this.splitKeywords(this.state.secondaryKeysText),
      content: this.state.content.trim(),
      constant: this.state.constant,
      selective: this.state.selective,
      enabled: this.state.enabled,
      insertionOrder: this.parseInsertionOrder(),
      position: this.state.position,
      caseSensitive: this.state.caseSensitive,
      matchWholeWords: this.state.matchWholeWords,
      probability: this.parseNumber(this.state.probabilityText, 100, 0, 100),
      excludeRecursion: this.state.excludeRecursion,
      depth: this.parseNumber(this.state.depthText, 0, 0, 999),
      scanDepth: this.parseNumber(this.state.scanDepthText, 0, 0, 999),
      role: this.state.role,
      group: this.state.group.trim(),
      groupOverride: this.state.groupOverride,
      groupWeight: this.parseNumber(this.state.groupWeightText, 100, 0, 999),
      automationId: this.state.automationId.trim(),
    }
  }

  private buildUpdateParams(): WorldInfoEntryUpdateParams {
    return {
      comment: this.state.comment.trim(),
      keys: this.splitKeywords(this.state.keysText),
      secondaryKeys: this.splitKeywords(this.state.secondaryKeysText),
      content: this.state.content.trim(),
      constant: this.state.constant,
      selective: this.state.selective,
      enabled: this.state.enabled,
      insertionOrder: this.parseInsertionOrder(),
      position: this.state.position,
      caseSensitive: this.state.caseSensitive,
      matchWholeWords: this.state.matchWholeWords,
      probability: this.parseNumber(this.state.probabilityText, 100, 0, 100),
      excludeRecursion: this.state.excludeRecursion,
      depth: this.parseNumber(this.state.depthText, 0, 0, 999),
      scanDepth: this.parseNumber(this.state.scanDepthText, 0, 0, 999),
      role: this.state.role,
      group: this.state.group.trim(),
      groupOverride: this.state.groupOverride,
      groupWeight: this.parseNumber(this.state.groupWeightText, 100, 0, 999),
      automationId: this.state.automationId.trim(),
    }
  }

  private splitKeywords(text: string): Array<string> {
    const result = new Array<string>()
    const parts = text.split(',')
    for (let index = 0; index < parts.length; index += 1) {
      const keyword = parts[index].trim()
      if (keyword.length > 0) {
        result.push(keyword)
      }
    }
    return result
  }

  private parseInsertionOrder(): number {
    return this.parseNumber(this.state.insertionOrderText, 100, -999999, 999999)
  }

  private parseNumber(text: string, fallback: number, min: number, max: number): number {
    const value = Number(text.trim())
    if (value !== value) {
      return fallback
    }
    return Math.min(Math.max(value, min), max)
  }
}
