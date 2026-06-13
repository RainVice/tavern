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

export function isPathInsideRoot(path: string, rootPath: string): boolean {
  const normalizedPath = normalizePath(path);
  const normalizedRoot = normalizePath(rootPath);
  if (normalizedPath === normalizedRoot) {
    return true;
  }
  return normalizedPath.startsWith(`${normalizedRoot}/`);
}

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

export function safeFileName(fileName: string, fallback: string = 'file'): string {
  return safePathToken(fileName, fallback);
}

export function safePathSegment(value: string, fallback: string = 'item'): string {
  return safePathToken(value, fallback);
}

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
