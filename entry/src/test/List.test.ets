import localUnitTest from './LocalUnit.test';
import modelProviderEditTest from './ModelProviderEdit.test';
import tavernRuntimeTest from './TavernRuntime.test';

export default function testsuite() {
  localUnitTest();
  modelProviderEditTest();
  tavernRuntimeTest();
}
