/**
 * 规范化路径分隔符为 `/`，并解析 `..` 和 `.` 路径段，保证后续比较和存储使用一致格式。
 * @param path 目标文件或目录路径。
 * @returns 规范化后的标准路径字符串。
 */
export function normalizePath(path: string): string {
  const parts = path.replace(/\\/g, '/').split('/');
  const normalized = new Array<string>();
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
 * 判断目标路径是否位于根路径之下，防止路径遍历攻击。
 * @param path 目标文件或目录路径。
 * @param rootPath Tavern 数据根路径。
 * @returns 路径位于根路径下时返回 true，否则返回 false。
 */
export function isPathInsideRoot(path: string, rootPath: string): boolean {
  const normalizedPath = normalizePath(path);
  const normalizedRoot = normalizePath(rootPath);
  if (normalizedPath === normalizedRoot) {
    return true;
  }
  return normalizedPath.startsWith(`${normalizedRoot}/`);
}

/**
 * 判断路径是否为安全的相对路径（无空段、无绝对路径前缀、无 `..`/`.` 回溯段、无空字符和反斜杠）。
 * @param path 目标文件或目录路径。
 * @returns 路径安全时返回 true，否则返回 false。
 */
export function isSafeRelativePath(path: string): boolean {
  if (path.length === 0 || path.startsWith('/') || path.startsWith('\\')) {
    return false;
  }
  if (path.indexOf('\0') >= 0 || path.indexOf('\\') >= 0) {
    return false;
  }
  const parts = path.split('/');
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index];
    if (part.length === 0 || part === '.' || part === '..') {
      return false;
    }
  }
  return true;
}

/**
 * 将文件名中的特殊字符（`~`、`/`、`\`、空字符）转义为安全表示形式，用于文件存储命名。
 * @param fileName 文件名称。
 * @param fallback 文件名经过转义后为空或为 `.`、`..` 时使用的默认值，默认为 `'file'`。
 * @returns 转义后的安全文件名。
 */
export function safeFileName(fileName: string, fallback: string = 'file'): string {
  return safePathToken(fileName, fallback);
}

/**
 * 将路径段中的特殊字符（`~`、`/`、`\`、空字符）转义为安全表示形式，确保可安全用于文件路径拼接。
 * @param value 要保存或比较的字段值。
 * @param fallback 转义后结果为空或为 `.`、`..` 时使用的默认值，默认为 `'item'`。
 * @returns 转义后的安全路径段。
 */
export function safePathSegment(value: string, fallback: string = 'item'): string {
  return safePathToken(value, fallback);
}

/**
 * 将输入值中的特殊字符（`~`、`/`、`\`、空字符）转义为安全表示形式。
 * @param value 待转义的字符串值。
 * @param fallback 转义后结果无效时使用的默认值。
 * @returns 转义后的安全字符串。
 */
function safePathToken(value: string, fallback: string): string {
  let result = '';
  const trimmed = value.trim();
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
  if (result.length === 0 || result === '.' || result === '..') {
    return fallback;
  }
  return result;
}
