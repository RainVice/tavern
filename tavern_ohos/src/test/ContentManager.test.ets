import { describe, it, expect } from '@ohos/hypium';
import {
  ContentManagerRuntime, EventBus,
  type ContentDownloadProgressPayload,
  type ContentExportData,
  type ContentItem,
  type ContentInstalledPayload, type RuntimeEvent,
  type PackageRecord,
} from '../../Index';

export default function contentManagerUnitTest() {
  describe('ContentManagerRuntime', () => {
    it('安装内容并跟踪状态', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ContentManagerRuntime(bus);
      let installed = false;
      bus.subscribe<ContentInstalledPayload>('content.installed', () => { installed = true; });
      const item = runtime.installContent('extension', 'url', 'https://example.com/ext.zip', '测试扩展');
      runtime.updateProgress(item.itemId, 50);
      runtime.completeInstall(item.itemId, '/data/ext/test', '1.0.0');
      const saved = runtime.getItem(item.itemId);
      expect(saved.status).assertEqual('installed');
      expect(saved.displayName).assertEqual('测试扩展');
      expect(saved.installPath).assertEqual('/data/ext/test');
      expect(saved.version).assertEqual('1.0.0');
      expect(installed).assertTrue();
    });

    it('按类型过滤内容', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ContentManagerRuntime(bus);
      runtime.installContent('extension', 'url', '', 'A');
      runtime.installContent('background', 'file', '', 'B');
      runtime.installContent('extension', 'url', '', 'C');
      expect(runtime.listContent('extension').length).assertEqual(2);
      expect(runtime.listContent('background').length).assertEqual(1);
      expect(runtime.listContent().length).assertEqual(3);
    });

    it('安装失败和移除', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ContentManagerRuntime(bus);
      const item = runtime.installContent('theme', 'url', '', 'X');
      runtime.failInstall(item.itemId, '网络错误');
      expect(runtime.getItem(item.itemId).status).assertEqual('failed');
      runtime.removeContent(item.itemId);
      { let t=false; try { runtime.getItem(item.itemId); } catch(e) { t=true; } expect(t).assertTrue(); };
    });

    it('包管理', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ContentManagerRuntime(bus);
      const pkg = runtime.registerPackage('语音包', 'asset', '2.0', 'author', '/data/voice');
      expect(runtime.listPackages().length).assertEqual(1);
      runtime.setPackageEnabled(pkg.packageId, false);
      expect(runtime.listPackages()[0].enabled).assertFalse();
      runtime.removePackage(pkg.packageId);
      expect(runtime.listPackages().length).assertEqual(0);
    });

    it('导出和导入', 0, () => {
      const bus1 = new EventBus();
      const rt1 = new ContentManagerRuntime(bus1);
      rt1.installContent('extension', 'url', '', 'E');
      rt1.registerPackage('P', 'extension', '1.0', 'a', '/p');
      const data = rt1.exportData();
      const bus2 = new EventBus();
      const rt2 = new ContentManagerRuntime(bus2);
      rt2.importData(data);
      expect(rt2.listContent().length).assertEqual(1);
      expect(rt2.listPackages().length).assertEqual(1);
    });

    it('读取和导出不会暴露内部内容与包对象', 0, () => {
      // 运行时实例。
      const runtime = new ContentManagerRuntime(new EventBus());
      const item = runtime.installContent('extension', 'url', 'https://example.com/a.zip', '扩展');
      item.displayName = '外部内容';
      item.metadata['source'] = 'external';
      expect(runtime.getItem(item.itemId).displayName).assertEqual('扩展');
      expect(runtime.getItem(item.itemId).metadata['source'] === undefined).assertTrue();
      const pkg = runtime.registerPackage('包', 'extension', '1.0', 'author', '/pkg');
      pkg.dependencies.push('外部依赖');
      expect(runtime.listPackages()[0].dependencies.length).assertEqual(0);
      const exported = runtime.exportData();
      exported.items[0].displayName = '导出内容';
      exported.packages[0].dependencies.push('导出依赖');
      expect(runtime.getItem(item.itemId).displayName).assertEqual('扩展');
      expect(runtime.listPackages()[0].dependencies.length).assertEqual(0);
    });

    it('下载进度会限制在有效范围', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ContentManagerRuntime(bus);
      let reported = 0;
      bus.subscribe<ContentDownloadProgressPayload>(
        'content.download.progress',
        (event: RuntimeEvent<ContentDownloadProgressPayload>) => {
          reported = event.payload.progress;
          event.payload.item.displayName = '事件修改';
        },
      );
      const item = runtime.installContent('theme', 'url', '', '主题');
      runtime.updateProgress(item.itemId, 180);
      expect(reported).assertEqual(100);
      expect(runtime.getItem(item.itemId).displayName).assertEqual('主题');
    });

    it('导入后新建内容和包不会复用已有 ID，且不会保留导入源引用', 0, () => {
      // 运行时实例。
      const runtime = new ContentManagerRuntime(new EventBus());
      const metadata: Record<string, string> = {};
      metadata['origin'] = 'import';
      const importedItem: ContentItem = {
        itemId: 'content-5',
        contentType: 'extension',
        source: 'url',
        sourceUrl: 'https://example.com/old.zip',
        displayName: '导入内容',
        version: '',
        status: 'pending',
        installPath: '',
        size: 0,
        metadata: metadata,
        error: '',
        createdAt: 1,
        updatedAt: 1,
      };
      const importedPackage: PackageRecord = {
        packageId: 'pkg-6',
        contentType: 'extension',
        displayName: '导入包',
        version: '1.0',
        author: 'author',
        description: '',
        installPath: '/old',
        enabled: true,
        dependencies: ['base'],
        createdAt: 1,
        updatedAt: 1,
      };
      const data: ContentExportData = {
        items: [importedItem],
        packages: [importedPackage],
      };
      runtime.importData(data);
      data.items[0].metadata['origin'] = 'external';
      data.packages[0].dependencies.push('external');
      const item = runtime.installContent('extension', 'url', '', '新内容');
      const pkg = runtime.registerPackage('新包', 'extension', '1.0', 'author', '/new');
      expect(item.itemId).assertEqual('content-6');
      expect(pkg.packageId).assertEqual('pkg-7');
      expect(runtime.getItem('content-5').metadata['origin']).assertEqual('import');
      expect(runtime.listPackages()[0].dependencies.length).assertEqual(1);
    });

    it('导入时拒绝覆盖已有内容或包 ID', 0, () => {
      // 运行时实例。
      const runtime = new ContentManagerRuntime(new EventBus());
      const item = runtime.installContent('extension', 'url', '', '已有内容');
      const pkg = runtime.registerPackage('已有包', 'extension', '1.0', 'author', '/pkg');
      const data = runtime.exportData();
      data.items[0].displayName = '覆盖内容';
      data.packages[0].displayName = '覆盖包';
      let itemConflict = false;
      let packageConflict = false;

      try {
        runtime.importData({ items: [data.items[0]], packages: new Array<PackageRecord>() });
      } catch (error) {
        itemConflict = true;
      }
      try {
        runtime.importData({ items: new Array<ContentItem>(), packages: [data.packages[0]] });
      } catch (error) {
        packageConflict = true;
      }

      expect(itemConflict).assertTrue();
      expect(packageConflict).assertTrue();
      expect(runtime.getItem(item.itemId).displayName).assertEqual('已有内容');
      expect(runtime.listPackages()[0].displayName).assertEqual(pkg.displayName);
    });
  });
}
