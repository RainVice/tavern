import { describe, it, expect } from '@ohos/hypium';
import { EventBus, GalleryRuntime, type GalleryExportData } from '../../Index';
export default function galleryUnitTest() {
  describe('GalleryRuntime', () => {
    it('添加和列出图片', 0, () => {
      const rt = new GalleryRuntime(new EventBus());
      rt.addImage('char-1', 'photo.png', 'image/png', '/data/photo.png');
      rt.addImage('char-1', 'sketch.jpg', 'image/jpeg', '/data/sketch.jpg');
      expect(rt.listImages('char-1').length).assertEqual(2);
      expect(rt.listImages().length).assertEqual(2);
    });
    it('设置 caption 和删除', 0, () => {
      const rt = new GalleryRuntime(new EventBus());
      const img = rt.addImage('char-1', 'x.png', 'image/png', '/x');
      rt.setCaption(img.imageId, '一只猫');
      expect(rt.getImage(img.imageId).caption).assertEqual('一只猫');
      rt.removeImage(img.imageId);
      { let t=false; try { rt.getImage(img.imageId); } catch(e) { t=true; } expect(t).assertTrue(); };
    });
    it('读取和导出不会暴露内部图片', 0, () => {
      const rt = new GalleryRuntime(new EventBus());
      const img = rt.addImage('char-1', 'x.png', 'image/png', '/x');
      img.caption = '外部 caption';
      img.tags.push('外部标签');
      expect(rt.getImage(img.imageId).caption).assertEqual('');
      expect(rt.getImage(img.imageId).tags.length).assertEqual(0);

      rt.setCaption(img.imageId, '内部 caption');
      const listed = rt.listImages('char-1');
      listed[0].caption = '列表修改';
      listed[0].tags.push('列表标签');
      const saved = rt.getImage(img.imageId);
      expect(saved.caption).assertEqual('内部 caption');
      expect(saved.tags.length).assertEqual(0);
      const exported = rt.exportData();
      exported.images[0].caption = '导出修改';
      expect(rt.getImage(img.imageId).caption).assertEqual('内部 caption');
    });
    it('导入后新建图片不会复用已有 ID', 0, () => {
      const rt = new GalleryRuntime(new EventBus());
      const data: GalleryExportData = {
        images: [{
          imageId: 'gallery-4',
          characterId: 'char-1',
          fileName: 'old.png',
          mimeType: 'image/png',
          path: '/old.png',
          caption: '',
          tags: [],
          createdAt: 1,
        }],
      };
      rt.importData(data);
      const created = rt.addImage('char-1', 'new.png', 'image/png', '/new.png');
      expect(created.imageId).assertEqual('gallery-5');
    });
  });
}
