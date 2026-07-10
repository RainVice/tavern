import { FileUtil, LogUtil, ObjectUtil, StrUtil } from '@pura/harmony-utils'
import { fileIo } from '@kit.CoreFileKit'


export namespace BaseStore {
  export abstract class File {
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

    protected writeText(text: string): number | undefined {
      let file: fileIo.File | undefined
      try {
        const filePath = this.getFilePath() ?? ""
        if (StrUtil.isBlank(filePath)) {
          throw new Error("文件路径无效")
        }
        file = FileUtil.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        return FileUtil.writeSync(file.fd, text, { offset: 0, encoding: 'utf-8' })
      } catch (e) {
        LogUtil.error(this.className, "写入文件内容失败：", this.filename, e)
        return undefined
      } finally {
        if (file) {
          FileUtil.close(file.fd); //关闭文件
        }
      }
    }
  }

  export abstract class Dir {
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
