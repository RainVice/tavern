import { FileUtil, LogUtil, ObjectUtil, StrUtil } from '@pura/harmony-utils'
import { fileIo } from '@kit.CoreFileKit'


export namespace BaseStore {
  export abstract class BaseFile {
    protected abstract readonly dirname: string
    protected abstract readonly filename: string
    protected readonly className = ObjectUtil.getClassName(this)

    protected getFilePath(): string | undefined {
      try {
        return FileUtil.getFilesDirPath(this.dirname, this.filename)
      } catch (e) {
        LogUtil.error(this.className, "创建/打开文件失败：", this.filename, e)
        return undefined
      }
    }

    protected openFile(): fileIo.File | undefined {
      try {
        const filePath = this.getFilePath() ?? ""
        if (StrUtil.isBlank(filePath)) {
          throw new Error("文件路径无效")
        }
        return FileUtil.openSync(filePath)
      } catch (e) {
        LogUtil.error(this.className, "打开文件失败：", this.filename, e)
        return undefined
      }
    }

    protected readText(): string | undefined {
      try {
        const filePath = this.getFilePath() ?? ""
        if (StrUtil.isBlank(filePath)) {
          throw new Error("文件路径无效")
        }
        return FileUtil.readTextSync(filePath)
      } catch (e) {
        LogUtil.error(this.className, "读取文件内容失败：", this.filename, e)
        return undefined
      }
    }

    protected async writeText(text: string): Promise<number | undefined> {
      try {
        const filePath = this.getFilePath() ?? ""
        if (StrUtil.isBlank(filePath)) {
          throw new Error("文件路径无效")
        }
        return await FileUtil.writeEasy(filePath, text, false)
      } catch (e) {
        LogUtil.error(this.className, "写入文件内容失败：", this.filename, e)
        return undefined
      }
    }
  }

  export abstract class BaseDir {
    protected abstract readonly dirname: string
    protected readonly className = ObjectUtil.getClassName(this)

    protected getDirPath(): string | undefined {
      try {
        return FileUtil.getFilesDirPath(this.dirname)
      } catch (e) {
        LogUtil.error(this.className, "创建/打开目录失败：", this.dirname, e)
        return undefined
      }
    }

    protected list(): string[] | undefined {
      try {
        const dirPath = this.getDirPath() ?? ""
        if (StrUtil.isBlank(dirPath)) {
          throw new Error("目录路径无效")
        }
        return FileUtil.listFileSync(dirPath)
      } catch (e) {
        LogUtil.error(this.className, "列出目录内容失败：", this.dirname, e)
        return undefined
      }
    }
  }
}
