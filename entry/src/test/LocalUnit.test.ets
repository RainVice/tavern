import { describe, it, expect } from '@ohos/hypium';
import { RouterName } from 'router';

export default function localUnitTest() {
  describe('routerName', () => {
    it('defines character card detail route', 0, () => {
      expect(RouterName.CharacterCardDetail).assertEqual('CharacterCardDetail');
    });
  });
}
