/**
 * 规范化路径格式：将反斜杠转换为正斜杠，解析 . 和 .. 段。用于文件路径标准化，确保路径比较和操作的可靠性。
 * @param path 待规范化的文件或目录路径，可能包含混用的反斜杠或相对路径段。
 * @returns 规范化后的路径字符串，所有反斜杠转换为正斜杠，. 和 .. 段被解析。
 */
export function normalizePath(path: string): string {
  const parts = path.replace(/\\/g, '/').split('/');
  const normalized = new Array<string>();
  /**
   * 遍历路径的每个段，过滤空段和当前目录段，处理父目录回溯。
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
 * 判断指定路径是否位于根路径内部，防止目录遍历攻击。用于文件操作前的安全检查，确保访问路径未越界。
 * @param path 待检查的文件或目录路径。
 * @param rootPath 根路径，作为安全边界。规范化后检查 path 是否以 rootPath 开头。
 * @returns 路径在根路径内返回 true，否则返回 false。
 */
export function isPathInsideRoot(path: string, rootPath: string): boolean {
  const normalizedPath = normalizePath(path);
  const normalizedRoot = normalizePath(rootPath);
  /**
   * 先判断路径是否完全等于根路径，再判断是否以根路径 + "/" 开头。
   */
  if (normalizedPath === normalizedRoot) {
    return true;
  }
  return normalizedPath.startsWith(`${normalizedRoot}/`);
}

/**
 * 判断路径是否为安全的相对路径，禁止空路径、绝对路径和包含空字符的路径。用于文件系统写入前的安全校验。
 * @param path 待检查的路径，将被验证是否为合法且安全的相对路径。
 * @returns 安全相对路径返回 true，否则返回 false。
 */
export function isSafeRelativePath(path: string): boolean {
  /**
   * 拒绝空路径和以 / 或 \\ 开头的绝对路径。
   */
  if (path.length === 0 || path.startsWith('/') || path.startsWith('\\')) {
    return false;
  }
  /**
   * 拒绝包含空字符或反斜杠的路径。
   */
  if (path.indexOf('\0') >= 0 || path.indexOf('\\') >= 0) {
    return false;
  }
  const parts = path.split('/');
  /**
   * 拒绝包含空段、当前目录段或父目录段的路径。
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
 * 将字符串安全的文件名称中的不安全字符进行编码。用于生成安全的文件名，避免路径注入。
 * @param fileName 原始文件名，可能包含不安全字符。
 * @param fallback 文件名无效时的默认值，默认 "file"。
 * @returns 安全的文件名，不安全字符被编码替换。
 */
export function safeFileName(fileName: string, fallback: string = 'file'): string {
  return safePathToken(fileName, fallback);
}

/**
 * 将字符串安全的路径段中的不安全字符进行编码。用于生成安全的路径段，避免路径遍历攻击。
 * @param value 原始路径段值，可能包含 / \ ~ 和空字符等不安全字符。
 * @param fallback 路径段无效时的默认值，默认 "item"。
 * @returns 安全的路径段，不安全字符被编码替换。
 */
export function safePathSegment(value: string, fallback: string = 'item'): string {
  return safePathToken(value, fallback);
}

/**
 * 将字符串中的不安全字符（~ / \\ 和空字符）编码为安全形式。
 * @param value 原始字符串。
 * @param fallback 结果无效时的回退值。
 * @returns 安全的路径标识符。
 */
function safePathToken(value: string, fallback: string): string {
  let result = '';
  const trimmed = value.trim();
  /**
   * 逐字符扫描，将 ~ 编码为 ~7e，/ 编码为 ~2f，\\ 编码为 ~5c，跳过空字符。
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
   * 如果结果为空或为 . 或 ..，使用 fallback 代替。
   */
  if (result.length === 0 || result === '.' || result === '..') {
    return fallback;
  }
  return result;
}
