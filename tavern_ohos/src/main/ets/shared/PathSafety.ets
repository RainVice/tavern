/**
 * 规范化 路径，保证后续比较和存储使用一致格式。
 * @param path 目标文件或目录路径。
 */
export function normalizePath(path: string): string {
  const parts = path.replace(/\\/g, '/').split('/');
  const normalized = new Array<string>();
  /**
   * 执行 for 的内部处理步骤，供当前模块复用。
   */
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index];
    if (part.length === 0 || part === '.') {
      continue;
    }
    if (part === '..') {
      if (normalized.length > 0 && normalized[normalized.length - 1] !== '..') {
        normalized.pop();
      } else {
        normalized.push(part);
      }
      continue;
    }
    normalized.push(part);
  }
  return normalized.join('/');
}

/**
 * 判断Path Inside Root 值是否满足条件。
 * @param path 目标文件或目录路径。
 * @param rootPath Tavern 数据根路径。
 * @returns 条件命中时返回 true，否则返回 false。
 */
export function isPathInsideRoot(path: string, rootPath: string): boolean {
  const normalizedPath = normalizePath(path);
  const normalizedRoot = normalizePath(rootPath);
  /**
   * 执行 if 的内部处理步骤，供当前模块复用。
   */
  if (normalizedPath === normalizedRoot) {
    return true;
  }
  return normalizedPath.startsWith(`${normalizedRoot}/`);
}

/**
 * 判断Safe Relative 路径是否满足条件。
 * @param path 目标文件或目录路径。
 * @returns 条件命中时返回 true，否则返回 false。
 */
export function isSafeRelativePath(path: string): boolean {
  /**
   * 执行 if 的内部处理步骤，供当前模块复用。
   */
  if (path.length === 0 || path.startsWith('/') || path.startsWith('\\')) {
    return false;
  }
  /**
   * 执行 if 的内部处理步骤，供当前模块复用。
   */
  if (path.indexOf('\0') >= 0 || path.indexOf('\\') >= 0) {
    return false;
  }
  const parts = path.split('/');
  /**
   * 执行 for 的内部处理步骤，供当前模块复用。
   */
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index];
    if (part.length === 0 || part === '.' || part === '..') {
      return false;
    }
  }
  return true;
}

/**
 * 执行 safeFileName 的内部处理步骤，供当前模块复用。
 * @param fileName 文件名称。
 */
export function safeFileName(fileName: string, fallback: string = 'file'): string {
  return safePathToken(fileName, fallback);
}

/**
 * 执行 safePathSegment 的内部处理步骤，供当前模块复用。
 * @param value 要保存或比较的字段值。
 */
export function safePathSegment(value: string, fallback: string = 'item'): string {
  return safePathToken(value, fallback);
}

/**
 * 执行 safePathToken 的内部处理步骤，供当前模块复用。
 * @param value 要保存或比较的字段值。
 */
function safePathToken(value: string, fallback: string): string {
  let result = '';
  const trimmed = value.trim();
  /**
   * 执行 for 的内部处理步骤，供当前模块复用。
   */
  for (let index = 0; index < trimmed.length; index += 1) {
    const code = trimmed.charCodeAt(index);
    if (code === 0) {
      continue;
    }
    if (trimmed[index] === '~') {
      result += '~7e';
    } else if (trimmed[index] === '/') {
      result += '~2f';
    } else if (trimmed[index] === '\\') {
      result += '~5c';
    } else {
      result += trimmed[index];
    }
  }
  /**
   * 执行 if 的内部处理步骤，供当前模块复用。
   */
  if (result.length === 0 || result === '.' || result === '..') {
    return fallback;
  }
  return result;
}
